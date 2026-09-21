import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/providers/price_mode_provider.dart';
import 'package:bakaloo_flutter_app/core/providers/store_provider.dart';
import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';

/// Theme manifests depend on the storefront and the fulfilling shop, not on the
/// price mode. Immutable and captured when a request STARTS: a response is only
/// ever stored under the key it was requested for.
@immutable
class ThemeScopeKey {
  const ThemeScopeKey({required this.storeKey, required this.shopScope});

  final String storeKey;

  /// `anon` or the sorted allocated shop ids joined by `,`.
  final String shopScope;

  String get id => '$storeKey|$shopScope';

  @override
  bool operator ==(Object other) =>
      other is ThemeScopeKey &&
      other.storeKey == storeKey &&
      other.shopScope == shopScope;

  @override
  int get hashCode => Object.hash(storeKey, shopScope);

  @override
  String toString() => 'ThemeScopeKey($id)';
}

/// Section manifests / tab-home content embed shop-scoped, price-mode-scoped
/// products, so the price mode is part of the key: retail and wholesale live
/// side by side and flipping between them invalidates nothing.
@immutable
class SectionScopeKey {
  const SectionScopeKey({
    required this.storeKey,
    required this.shopScope,
    required this.priceMode,
    required this.tabKey,
  });

  final String storeKey;
  final String shopScope;

  /// `retail` | `wholesale`.
  final String priceMode;
  final String tabKey;

  ThemeScopeKey get themeKey =>
      ThemeScopeKey(storeKey: storeKey, shopScope: shopScope);

  String get id => '$storeKey|$shopScope|$priceMode|$tabKey';

  @override
  bool operator ==(Object other) =>
      other is SectionScopeKey &&
      other.storeKey == storeKey &&
      other.shopScope == shopScope &&
      other.priceMode == priceMode &&
      other.tabKey == tabKey;

  @override
  int get hashCode => Object.hash(storeKey, shopScope, priceMode, tabKey);

  @override
  String toString() => 'SectionScopeKey($id)';
}

/// Everything that can make two storefront payloads differ for one customer.
@immutable
class StorefrontScope {
  const StorefrontScope({
    required this.storeKey,
    required this.shopScope,
    required this.priceMode,
  });

  final String storeKey;
  final String shopScope;
  final String priceMode;

  ThemeScopeKey get themeKey =>
      ThemeScopeKey(storeKey: storeKey, shopScope: shopScope);

  SectionScopeKey sectionKey(String tabKey) => SectionScopeKey(
        storeKey: storeKey,
        shopScope: shopScope,
        priceMode: priceMode,
        tabKey: tabKey,
      );

  @override
  bool operator ==(Object other) =>
      other is StorefrontScope &&
      other.storeKey == storeKey &&
      other.shopScope == shopScope &&
      other.priceMode == priceMode;

  @override
  int get hashCode => Object.hash(storeKey, shopScope, priceMode);

  @override
  String toString() => 'StorefrontScope($storeKey|$shopScope|$priceMode)';
}

class _ShopScopeNotifier extends Notifier<String> {
  @override
  String build() {
    final ValueListenable<String> source = AppCacheManager.shopScopeListenable;
    void onChanged() {
      if (ref.mounted && source.value != state) {
        state = source.value;
      }
    }

    source.addListener(onChanged);
    ref.onDispose(() => source.removeListener(onChanged));
    return source.value;
  }
}

/// Riverpod mirror of the persisted shop scope. `AppCacheManager` publishes a
/// new scope only AFTER persisting it, so every listener sees a consistent one.
final NotifierProvider<_ShopScopeNotifier, String> shopScopeProvider =
    NotifierProvider<_ShopScopeNotifier, String>(_ShopScopeNotifier.new);

/// The active storefront scope. Every provider that serves store-, shop- or
/// price-mode-specific content watches this, so a change re-keys them all at
/// once and nothing keyed by the previous scope can be read again.
final Provider<StorefrontScope> storefrontScopeProvider =
    Provider<StorefrontScope>((Ref ref) {
  final String storeKey = ref.watch(selectedStoreProvider.select((s) => s.id));
  final String shopScope = ref.watch(shopScopeProvider);
  final PriceMode mode = ref.watch(priceModeProvider);
  return StorefrontScope(
    storeKey: storeKey,
    shopScope: shopScope,
    priceMode: mode == PriceMode.wholesale ? 'wholesale' : 'retail',
  );
});
