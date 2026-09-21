import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/providers/store_provider.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_service.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/core/storefront/layout_keys.dart';
import 'package:bakaloo_flutter_app/core/storefront/layout_providers.dart';
import 'package:bakaloo_flutter_app/core/storefront/storefront_scope.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';

// The Theme Builder (backend `/theme/tabs`) is the ONLY source of storefront
// chrome. There is deliberately no bundled fallback theme: while a store's
// theme is unresolved the UI shows neutral placeholders (see
// [RemoteTheme.neutral]) — never another store's theme and never a legacy one.

/// Epoch milliseconds of the last home scroll event, stamped by the home
/// screen so background refresh can wait until the user stops scrolling.
int homeScrollLastEventMs = 0;

/// The active storefront's theme manifest. Keyed by (store, shop scope): a
/// shop change swaps to a different provider instance — the previous shop's
/// theme is unreachable through this provider.
final Provider<AsyncValue<TabThemesResponse>> tabThemesProvider =
    Provider<AsyncValue<TabThemesResponse>>((Ref ref) {
  final ThemeKey key = ref.watch(
    storefrontScopeProvider.select((StorefrontScope s) => s.themeKey),
  );
  return ref.watch(tabThemesControllerProvider(key));
});

/// The tabs of the active storefront, or null until its theme has loaded.
final Provider<List<TabThemeEntry>?> themeTabsProvider =
    Provider<List<TabThemeEntry>?>((Ref ref) {
  return ref.watch(tabThemesProvider).value?.tabs;
});

/// True once the active storefront's own theme is available (from memory,
/// disk, or the network).
final Provider<bool> themeReadyProvider = Provider<bool>((Ref ref) {
  return ref.watch(tabThemesProvider.select((a) => a.hasValue));
});

/// The tab being shown. `selectedCategoryIdProvider` is the raw user choice
/// (`''` = none yet); this resolves it against the active storefront's tabs so
/// an unknown/removed tab or a fresh store lands on its default tab.
final Provider<String> activeTabKeyProvider = Provider<String>((Ref ref) {
  final String selected = ref.watch(selectedCategoryIdProvider);
  final List<TabThemeEntry>? tabs = ref.watch(themeTabsProvider);
  if (tabs != null && tabs.isNotEmpty) {
    if (tabs.any((TabThemeEntry tab) => tab.tabKey == selected)) {
      return selected;
    }
    return resolveDefaultTab(tabs).tabKey;
  }
  // Theme not resolved yet: start fetching the requested (or 'all') manifest
  // in parallel with the theme instead of waiting for it.
  return selected.isEmpty ? 'all' : selected;
});

/// Theme of the active tab. Neutral while the theme is unresolved.
final Provider<RemoteTheme> activeTabThemeProvider =
    Provider<RemoteTheme>((Ref ref) {
  final List<TabThemeEntry>? tabs = ref.watch(themeTabsProvider);
  if (tabs == null || tabs.isEmpty) {
    return _neutralTheme;
  }
  final String tabKey = ref.watch(activeTabKeyProvider);
  final TabThemeEntry entry = tabs.firstWhere(
    (TabThemeEntry tab) => tab.tabKey == tabKey,
    orElse: () => resolveDefaultTab(tabs),
  );
  return entry.resolveForUser(_currentUserId());
});

final RemoteTheme _neutralTheme = RemoteTheme.neutral();

final StreamProvider<Map<String, dynamic>> socketThemeUpdateStreamProvider =
    StreamProvider<Map<String, dynamic>>((Ref ref) {
  return ref.watch(socketServiceProvider).themeUpdateStream;
});

String? _currentUserId() {
  try {
    final dynamic cachedUser = HiveService.userBox.get('user');
    if (cachedUser is Map) {
      final Map<String, dynamic> user = Map<String, dynamic>.from(cachedUser);
      final dynamic idValue = user['id'] ?? user['userId'];
      if (idValue is String && idValue.trim().isNotEmpty) {
        return idValue.trim();
      }
    }
  } catch (error) {
    debugPrint('[Theme] user lookup failed: $error');
  }
  return null;
}
