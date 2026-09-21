import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/providers/price_mode_provider.dart';
import 'package:bakaloo_flutter_app/core/providers/store_provider.dart';
import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
import 'package:bakaloo_flutter_app/core/storefront/layout_keys.dart';

/// Everything that can make two storefront payloads differ for one customer.
///
/// This is the single source of truth for "which storefront am I looking at".
/// Every provider that fetches or caches storefront content watches
/// [storefrontScopeProvider], so a change of shop, store or price mode yields
/// brand-new provider instances keyed by the new scope — nothing keyed by the
/// old scope can be read again, and no hand-maintained invalidation list is
/// needed.
@immutable
class StorefrontScope {
  const StorefrontScope({
    required this.storeKey,
    required this.shopScope,
    required this.priceMode,
  });

  final String storeKey;

  /// `anon` or the sorted allocated shop ids joined by `,`.
  final String shopScope;

  /// `retail` | `wholesale`.
  final String priceMode;

  ThemeKey get themeKey => ThemeKey(storeKey: storeKey, shopScope: shopScope);

  SectionKey sectionKey(String tabKey) => SectionKey(
        storeKey: storeKey,
        shopScope: shopScope,
        priceMode: priceMode,
        tabKey: tabKey,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
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

/// Riverpod mirror of the persisted shop scope. `AppCacheManager` updates the
/// underlying notifier only AFTER the new scope is persisted, so listeners
/// always observe a consistent scope.
final shopScopeProvider =
    NotifierProvider<_ShopScopeNotifier, String>(_ShopScopeNotifier.new);

/// The active storefront scope (store + shop + price mode).
final storefrontScopeProvider = Provider<StorefrontScope>((Ref ref) {
  final String storeKey = ref.watch(selectedStoreProvider.select((s) => s.id));
  final String shopScope = ref.watch(shopScopeProvider);
  final PriceMode mode = ref.watch(priceModeProvider);
  return StorefrontScope(
    storeKey: storeKey,
    shopScope: shopScope,
    priceMode: mode == PriceMode.wholesale ? 'wholesale' : 'retail',
  );
});
