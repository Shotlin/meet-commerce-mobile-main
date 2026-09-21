import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';

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
    final stored =
        HiveService.settingsBox.get(StorageKeys.priceMode) as String?;
    return stored == 'wholesale' ? PriceMode.wholesale : PriceMode.retail;
  }

  Future<void> toggle() async {
    final next =
        state == PriceMode.retail ? PriceMode.wholesale : PriceMode.retail;
    await HiveService.settingsBox.put(StorageKeys.priceMode, next.name);
    state = next;

    // Price mode is part of every storefront cache key
    // (`StorefrontScope.priceMode`): retail and wholesale content live side by
    // side and every provider that serves product data watches the scope, so it
    // rebuilds for the new mode on its own. Nothing is wiped and nothing is
    // invalidated by hand — the theme (mode-independent) is not touched.
    //
    // Each mode owns a separate cart, so that is the one thing that must be
    // re-read explicitly (badge, cart screen, checkout).
    ref.invalidate(cartProvider);
  }
}
