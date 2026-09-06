import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';
import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/providers/home_provider.dart';

part 'price_mode_provider.g.dart';

/// Which price a customer wants to browse at — a self-service view toggle,
/// not a KYC-gated account type. Applied server-side via a `priceMode` query
/// param sent on every product request (see ApiInterceptor), which serves
/// each product's admin-set `wholesale_price` (falling back to the normal
/// retail price where none is set) instead of `price`/`sale_price` when set
/// to wholesale. Cart/checkout still price using whatever was shown at
/// add-to-cart time — they don't re-resolve the mode themselves, so this
/// toggle only affects Browse-time display, not already-added cart items.
enum PriceMode { retail, wholesale }

@Riverpod(keepAlive: true)
class PriceModeNotifier extends _$PriceModeNotifier {
  @override
  PriceMode build() {
    final stored = HiveService.settingsBox.get(StorageKeys.priceMode) as String?;
    return stored == 'wholesale' ? PriceMode.wholesale : PriceMode.retail;
  }

  void toggle() {
    final next = state == PriceMode.retail ? PriceMode.wholesale : PriceMode.retail;
    state = next;
    unawaited(HiveService.settingsBox.put(StorageKeys.priceMode, next.name));

    // The local Hive product-list cache (ProductRepositoryImpl) is keyed by
    // shop scope only, not price mode — without clearing it here, switching
    // modes would keep serving whichever mode happened to populate the
    // cache first. Also invalidate the currently-visible home providers so
    // an open Home screen re-fetches immediately instead of only on next
    // cold start (mirrors auth_notifier.dart's
    // _invalidateShopScopedHomeProviders, which does the same for shop
    // allocation changes).
    unawaited(AppCacheManager.clearShopScopedCaches());
    try {
      ref.invalidate(homeProvider);
    } catch (_) {}
    try {
      ref.invalidate(homeFeaturedProductsProvider);
    } catch (_) {}
    try {
      ref.invalidate(homeDealsProvider);
    } catch (_) {}
    try {
      ref.invalidate(homeTrendingProductsProvider);
    } catch (_) {}
    try {
      ref.invalidate(homeNewArrivalsProvider);
    } catch (_) {}
  }
}
