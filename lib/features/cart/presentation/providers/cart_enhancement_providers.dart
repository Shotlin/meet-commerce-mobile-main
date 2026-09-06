import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/cart/data/datasources/cart_enhancements_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/bill_summary_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/payment_offer_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/tip_preset_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';

part 'cart_enhancement_providers.g.dart';

final cartEnhancementsDataSourceProvider =
    Provider<CartEnhancementsRemoteDataSource>((Ref ref) {
  return CartEnhancementsRemoteDataSource(ref.watch(apiClientProvider));
});

@riverpod
class BillSummaryNotifier extends _$BillSummaryNotifier {
  @override
  Future<BillSummaryEntity> build() async {
    final cart = await ref.watch(cartProvider.future);
    if (cart.isEmpty) {
      return BillSummaryEntity.empty();
    }

    // Watch the applied coupon so the bill summary rebuilds whenever the user
    // applies or removes a coupon, without requiring a separate refresh call.
    final appliedCoupon = ref.watch(checkoutProvider).appliedCoupon;

    // Watch the confirmed Quick Delivery selection so the bill (and the
    // surcharge line + faster delivery estimate that come with it) rebuild
    // the moment the customer confirms it in the schedule sheet — this was
    // previously never sent to the backend at all, so the surcharge silently
    // never applied to the total.
    final quickDeliverySelected = ref.watch(
      checkoutProvider.select(
        (s) => s.selectedDeliverySlot?.quickDeliverySelected ?? false,
      ),
    );

    // BUG FIX: this previously never sent an addressId at all, so the
    // preview always priced delivery against the customer's DEFAULT saved
    // address — even when they'd picked a different one for this order —
    // while placeOrder() (orders.service.js) always uses the real submitted
    // address. Ordering to a non-default address showed one delivery
    // fee/free-delivery threshold here and charged a different one at
    // checkout. `cartSelectedAddress` already resolves the right address
    // (checkout selection, falling back to default) — it just wasn't wired
    // into this request.
    final selectedAddress = ref.watch(cartSelectedAddressProvider);

    final result = await ref.read(cartEnhancementsDataSourceProvider).getCartSummary(
          quickDeliverySelected: quickDeliverySelected,
          addressId: selectedAddress?.id,
        );

    return result.fold(
      (failure) => throw StateError(failure.message),
      (summary) {
        // A manually-typed coupon code lives in client-side Riverpod state,
        // not the server session, so it isn't reflected in the backend
        // response at all. `summary.couponDiscount`/`totalPayable` may
        // already carry an auto-applied first-time-offer discount though
        // (backend-resolved, no customer action needed) — a manual coupon
        // takes priority over that and replaces it rather than stacking on
        // top (single discount slot, matching OrdersService.placeOrder()'s
        // rule), so the auto-discount amount is added back into the pre-tax
        // total before the coupon discount is subtracted (see
        // preTaxTotalOld below).
        //
        // CASHBACK/FREE_DELIVERY coupons always have discountAmount == 0
        // by backend design (they don't reduce the bill — a cashback is a
        // separate wallet credit after delivery, free delivery waives the
        // delivery fee instead of subtracting from the total). Previously
        // this guard only checked discountAmount > 0, so applying one of
        // these silently changed nothing on screen — the customer saw the
        // "applied" banner but the bill looked untouched, indistinguishable
        // from the coupon not working at all.
        if (appliedCoupon == null) {
          return summary;
        }

        final hasDiscount = appliedCoupon.discountAmount > 0;
        final hasFreeDelivery = appliedCoupon.freeDelivery;
        final hasCashback = appliedCoupon.cashbackAmount > 0;
        if (!hasDiscount && !hasFreeDelivery && !hasCashback) {
          return summary;
        }

        final discount = appliedCoupon.discountAmount;
        final basePayable =
            summary.totalPayable > 0 ? summary.totalPayable : summary.toPay.finalAmount;

        // BUG FIX: GST is computed server-side on the PRE-TAX total, i.e.
        // AFTER the auto-applied discount but BEFORE tip — see
        // bill-summary.service.js's `preTaxTotal = itemTotalDiscounted -
        // autoAppliedDiscount + feesTotal` followed by `gstAmount =
        // preTaxTotal * gstRate`. Naively subtracting the manual coupon's
        // discount straight from the tax-INCLUSIVE total (as this used to
        // do) silently keeps the OLD auto-discount's tax baked in, so the
        // displayed total drifts from what checkout will actually charge
        // whenever GST is enabled and the coupon's discount differs from
        // the auto-applied one it replaces (verified: subtotal ₹1000,
        // auto-discount ₹100, coupon discount ₹50, GST 18% — old code
        // showed ₹1112, real charge is ₹1121). Fix: derive the effective
        // GST rate from what the backend already computed for this exact
        // cart (tax ÷ pre-tax-total-at-the-OLD-discount), then reapply that
        // same rate to the pre-tax total at the NEW discount — this stays a
        // no-op (rate resolves to 0) whenever GST is disabled.
        final gstAmount = summary.fees
            .firstWhere((f) => f.code == 'GST', orElse: () => const FeeLine())
            .amount;
        final preTaxTotalOld = basePayable - gstAmount - summary.tipAmount;
        final gstRate = (gstAmount > 0 && preTaxTotalOld > 0)
            ? gstAmount / preTaxTotalOld
            : 0.0;
        var preTaxTotalNew =
            (preTaxTotalOld + summary.couponDiscount - discount).clamp(0.0, double.infinity);

        var deliveryFee = summary.deliveryFee;
        if (hasFreeDelivery && !deliveryFee.isFree) {
          // The FTO's own free-delivery waiver (if any) is already reflected
          // in preTaxTotalOld's delivery component via the backend response
          // — only waive here (reducing the pre-tax total, same as the
          // discount above, so tax is recomputed on the smaller base too)
          // when delivery wasn't already free.
          preTaxTotalNew =
              (preTaxTotalNew - deliveryFee.amount).clamp(0.0, double.infinity);
          deliveryFee = deliveryFee.copyWith(amount: 0, isFree: true, freeIn: 0);
        }

        final gstAmountNew = preTaxTotalNew * gstRate;
        final newPayable = preTaxTotalNew + gstAmountNew + summary.tipAmount;

        // The "Your savings" breakdown is computed server-side from whichever
        // auto-applied discount was active — first-time-offer OR cart-
        // milestone (bill-summary.service.js never sets both at once, see
        // its "single discount slot" comment) — and the backend has no idea
        // a manual coupon exists client-side. When the coupon replaces that
        // auto-discount above (via preTaxTotalOld, which adds back
        // summary.couponDiscount regardless of which of the two it came
        // from), its now-stale line must be dropped here too, or the savings
        // card keeps showing a reward that was actually replaced, disagreeing
        // with the main bill row about which reward is active.
        //
        // Reported bug: this used to only check for a 'first_time_offer'
        // line — a customer who unlocked a cart-milestone discount and then
        // applied a coupon code still saw the milestone's rupee amount
        // counted in "Your savings" (inflating savings.total) even though
        // checkout no longer actually applied it, i.e. exactly the
        // "sometimes right, sometimes wrong" totals customers reported.
        var savings = summary.savings;
        const autoDiscountTypes = <String>{'first_time_offer', 'cart_milestone'};
        final autoDiscountLines = savings.items
            .where((item) => autoDiscountTypes.contains(item.type))
            .toList();
        if (autoDiscountLines.isNotEmpty) {
          final autoDiscountAmount = autoDiscountLines.fold<double>(
            0,
            (sum, item) => sum + item.amount,
          );
          savings = savings.copyWith(
            total:
                (savings.total - autoDiscountAmount).clamp(0.0, double.infinity),
            items: savings.items
                .where((item) => !autoDiscountTypes.contains(item.type))
                .toList(),
          );
        }

        return summary.copyWith(
          couponDiscount: discount,
          totalPayable: newPayable,
          deliveryFee: deliveryFee,
          savings: savings,
          firstTimeOffer: null,
        );
      },
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

@riverpod
class PaymentOffersNotifier extends _$PaymentOffersNotifier {
  @override
  Future<List<PaymentOfferEntity>> build() async {
    final summary = await ref.watch(billSummaryProvider.future);
    final result = await ref
        .read(cartEnhancementsDataSourceProvider)
        .getPaymentOffers(summary.itemTotal.discounted);

    return result.fold(
      (failure) => throw StateError(failure.message),
      (offers) => offers,
    );
  }
}

@riverpod
Future<List<TipPresetEntity>> tipPresets(Ref ref) async {
  final result =
      await ref.read(cartEnhancementsDataSourceProvider).getTipPresets();
  return result.fold(
    (failure) => throw StateError(failure.message),
    (presets) => presets,
  );
}

@riverpod
class CartTipNotifier extends _$CartTipNotifier {
  @override
  double build() {
    final cartAsync = ref.watch(cartProvider);
    return cartAsync.asData?.value.tipAmount ?? 0;
  }

  Future<void> setTip(double amount) async {
    final previous = state;
    state = amount;

    final result =
        await ref.read(cartEnhancementsDataSourceProvider).updateTip(amount);
    result.fold(
      (_) {
        state = previous;
      },
      (_) {
        ref.invalidate(billSummaryProvider);
      },
    );
  }

  void clearTip() {
    state = 0;
  }
}

@riverpod
class DeliveryInstructionsNotifier extends _$DeliveryInstructionsNotifier {
  @override
  String build() {
    final cartAsync = ref.watch(cartProvider);
    return cartAsync.asData?.value.deliveryInstructions ?? '';
  }

  Future<void> setInstructions(String instructions) async {
    final previous = state;
    state = instructions;

    final result = await ref
        .read(cartEnhancementsDataSourceProvider)
        .updateDeliveryInstructions(instructions);
    result.fold(
      (_) {
        state = previous;
      },
      (_) {},
    );
  }
}

@riverpod
Future<List<Map<String, dynamic>>> priceDropProducts(Ref ref) async {
  final result =
      await ref.read(cartEnhancementsDataSourceProvider).getPriceDropProducts();
  return result.fold(
    (failure) => throw StateError(failure.message),
    (products) => products,
  );
}

@riverpod
Future<List<Map<String, dynamic>>> lastMinuteProducts(Ref ref) async {
  final result = await ref
      .read(cartEnhancementsDataSourceProvider)
      .getLastMinuteProducts();
  return result.fold(
    (failure) => throw StateError(failure.message),
    (products) => products,
  );
}

/// "Quick Add" rail on the cart screen — ~60% popular items from the same
/// categories already in the cart, ~30% from admin-configured related
/// categories, and the remainder a random popular pick (all resolved
/// server-side in cart.controller.js#getQuickAdd, which already excludes
/// whatever's currently in the cart). Re-fetches on every cart change since
/// the backend needs the up-to-date item/category set to exclude correctly.
@riverpod
Future<List<ProductEntity>> cartQuickAddProducts(Ref ref) async {
  final cart = await ref.watch(cartProvider.future);
  if (cart.isEmpty) {
    return const <ProductEntity>[];
  }

  final result =
      await ref.read(cartEnhancementsDataSourceProvider).getCartQuickAdd();
  return result.fold(
    (failure) => throw StateError(failure.message),
    (products) => products,
  );
}

@riverpod
AddressEntity? cartSelectedAddress(Ref ref) {
  final checkoutState = ref.watch(checkoutProvider);
  if (checkoutState.selectedAddress != null) {
    return checkoutState.selectedAddress;
  }

  final addresses = ref.watch(addressProvider);
  return addresses.when(
    data: (list) => list.isNotEmpty
        ? list.firstWhere((a) => a.isDefault, orElse: () => list.first)
        : null,
    loading: () => null,
    error: (_, __) => null,
  );
}

@riverpod
class TipTabNotifier extends _$TipTabNotifier {
  @override
  int build() => 0;

  void setTab(int tab) {
    state = tab;
  }
}
