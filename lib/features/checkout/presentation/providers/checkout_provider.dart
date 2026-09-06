import 'dart:async';

import 'package:dio/dio.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/constants/app_constants.dart';
import 'package:bakaloo_flutter_app/core/analytics/analytics_service.dart';
import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/data/datasources/order_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/checkout/data/repositories/checkout_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/checkout_summary_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/coupon_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/delivery_slot_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/usecases/place_order.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/coupon_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/store_status_provider.dart';
import 'package:bakaloo_flutter_app/features/payments/presentation/providers/payment_provider.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:bakaloo_flutter_app/routing/app_router.dart';

part 'checkout_provider.freezed.dart';
part 'checkout_provider.g.dart';

typedef CartValidationEntity = CartValidationResult;

// `wallet` was retired as an exclusive payment method — wallet balance is
// now an orthogonal toggle (see CheckoutState.useWallet) that can combine
// with either COD or online payment, applied as a discount against
// whichever method is chosen. The backend still accepts the legacy
// paymentMethod:'WALLET' value from any not-yet-updated app install; it
// simply can never be sent by this build anymore.
enum PaymentMethod {
  cod,
  online,
}

extension PaymentMethodX on PaymentMethod {
  String get apiValue => switch (this) {
        PaymentMethod.cod => 'COD',
        PaymentMethod.online => 'ONLINE',
      };

  String get title => switch (this) {
        PaymentMethod.cod => 'Cash on Delivery',
        PaymentMethod.online => 'Pay Online',
      };
}

enum CheckoutStep {
  address,
  coupon,
  payment,
  review,
}

@freezed
abstract class CheckoutState with _$CheckoutState {
  const factory CheckoutState({
    AddressEntity? selectedAddress,
    CouponEntity? appliedCoupon,
    @Default(PaymentMethod.online) PaymentMethod paymentMethod,
    CartValidationEntity? validatedCart,
    @Default(CheckoutStep.address) CheckoutStep currentStep,
    @Default(false) bool isPlacingOrder,
    String? errorMessage,
    // Delivery slot — null means ASAP (default)
    SelectedDeliverySlot? selectedDeliverySlot,
    // Wallet-balance toggle — explicit opt-in only, same convention as
    // Quick Delivery. Applies on top of `paymentMethod`, offsetting the
    // total rather than replacing the method.
    @Default(false) bool useWallet,
  }) = _CheckoutState;
}

class CheckoutPlacementResult {
  const CheckoutPlacementResult({
    this.order,
    this.errorMessage,
    this.handedOffToPayment = false,
  });

  final PlacedOrderEntity? order;
  final String? errorMessage;
  final bool handedOffToPayment;

  bool get isSuccess => order != null && errorMessage == null;
}

final orderRemoteDataSourceProvider =
    Provider<OrderRemoteDataSource>((Ref ref) {
  return OrderRemoteDataSource(ref.watch(apiClientProvider));
});

final checkoutRepositoryProvider = Provider<CheckoutRepository>((Ref ref) {
  return CheckoutRepositoryImpl(
    remoteDataSource: ref.watch(orderRemoteDataSourceProvider),
  );
});

final placeOrderUseCaseProvider = Provider<PlaceOrderUseCase>((Ref ref) {
  return PlaceOrderUseCase(ref.watch(checkoutRepositoryProvider));
});

// `keepAlive: true` — this state (selected address, applied coupon, payment
// method, delivery slot) represents an in-progress checkout flow spanning
// Cart -> Checkout, both of which watch this provider. `checkout` is a
// nested child route of `/cart` (see app_router.dart); pushing it rebuilds
// the `/cart` branch's widget identity, which — combined with autoDispose —
// tore this provider down and rebuilt it fresh with default state (no
// listener bridges the gap), silently discarding the applied coupon and any
// selected delivery slot the instant Checkout opened. keepAlive removes that
// window entirely; the state is explicitly cleared by removeCoupon() /
// clearDeliverySlot() / order completion instead.
@Riverpod(keepAlive: true)
class CheckoutNotifier extends _$CheckoutNotifier {
  @override
  CheckoutState build() {
    ref
      ..listen<AsyncValue<List<AddressEntity>>>(addressProvider, (_, next) {
        next.whenData(_syncAddresses);
      })
      ..listen<AsyncValue<CartEntity>>(cartProvider, (_, next) {
        next.whenData(_syncCart);
      });

    // `ref.read`, not `ref.watch` — these only seed the state the first time
    // this provider builds. Using `watch` here previously re-ran build() in
    // full on every single address/cart change (e.g. the cart revalidation
    // that runs when proceeding to checkout), discarding appliedCoupon and
    // selectedDeliverySlot in the process — the `ref.listen` calls above
    // already handle every subsequent change incrementally via
    // _syncAddresses/_syncCart, which preserve the rest of the state.
    final initialAddresses = switch (ref.read(addressProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final initialCart = switch (ref.read(cartProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };

    return CheckoutState(
      selectedAddress: _defaultAddress(initialAddresses),
      validatedCart: initialCart == null
          ? null
          : CartValidationResult(
              valid: true,
              cart: initialCart,
            ),
    );
  }

  void selectAddress(AddressEntity address) {
    state = state.copyWith(
      selectedAddress: address,
      currentStep: CheckoutStep.coupon,
      errorMessage: null,
    );
  }

  void selectPaymentMethod(PaymentMethod method) {
    state = state.copyWith(
      paymentMethod: method,
      currentStep: CheckoutStep.review,
      errorMessage: null,
    );
  }

  /// Toggles applying wallet balance against the total, on top of whichever
  /// [PaymentMethod] is currently selected — does not change the method
  /// itself.
  void setUseWallet(bool value) {
    state = state.copyWith(useWallet: value, errorMessage: null);
  }

  Future<bool> applyCoupon(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Enter a coupon code to continue.',
      );
      return false;
    }

    final cartTotal = subtotal;
    if (cartTotal <= 0) {
      state = state.copyWith(
        errorMessage: 'Your cart is empty.',
      );
      return false;
    }

    final result = await ref.read(validateCouponUseCaseProvider).call(
          code: normalizedCode,
          cartTotal: cartTotal,
        );

    return result.fold(
      (failure) {
        final message = _mapCouponError(failure.message);
        // Re-validating the coupon that's currently applied (e.g. the user
        // re-tapped it, or a background re-check ran) and getting an error
        // back means it's no longer usable — detach it instead of leaving
        // it showing as "applied" with no way to tell it's actually stuck.
        // Reported bug: an error occurred, but the coupon stayed set on the
        // cart with no automatic (or, previously, even manual) removal.
        final isCurrentlyAppliedCoupon =
            state.appliedCoupon?.code == normalizedCode;
        state = state.copyWith(
          errorMessage: message,
          appliedCoupon: isCurrentlyAppliedCoupon ? null : state.appliedCoupon,
        );
        return false;
      },
      (coupon) {
        state = state.copyWith(
          appliedCoupon: coupon,
          currentStep: CheckoutStep.payment,
          errorMessage: null,
        );
        unawaited(
          ref.read(analyticsServiceProvider).logCouponApplied(
                coupon.code,
                coupon.discountAmount,
              ),
        );
        return true;
      },
    );
  }

  void removeCoupon() {
    state = state.copyWith(
      appliedCoupon: null,
      currentStep: CheckoutStep.coupon,
      errorMessage: null,
    );
  }

  /// Clears the order-specific selections (applied coupon, delivery slot,
  /// payment method) once an order has been successfully placed. Needed
  /// because [CheckoutNotifier] is `keepAlive` — without this, a coupon or
  /// quick-delivery selection from a completed order would silently carry
  /// over and show as "applied" on the next one. `selectedAddress` is left
  /// alone; it's a delivery preference, not order-specific, and stays
  /// correctly in sync via `_syncAddresses`.
  void resetForNewOrder() {
    state = state.copyWith(
      appliedCoupon: null,
      selectedDeliverySlot: null,
      paymentMethod: PaymentMethod.online,
      useWallet: false,
      currentStep: CheckoutStep.address,
      errorMessage: null,
    );
  }

  /// Save the user's delivery slot selection (ASAP or a specific time window).
  void selectDeliverySlot(SelectedDeliverySlot slot) {
    state = state.copyWith(selectedDeliverySlot: slot, errorMessage: null);
  }

  /// Reset delivery slot to ASAP (called when cart is cleared or order succeeds).
  void clearDeliverySlot() {
    state = state.copyWith(selectedDeliverySlot: null);
  }

  /// Maps raw backend coupon error messages / codes to user-friendly copy.
  String _mapCouponError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('uuid') || lower.contains('syntax')) {
      return 'This coupon is not available.';
    }
    if (lower.contains('expired')) {
      return 'This coupon has expired.';
    }
    if (lower.contains('minimum') ||
        lower.contains('min_order') ||
        lower.contains('min order')) {
      return raw; // already includes the ₹ amount — keep as is
    }
    if (lower.contains('usage limit') || lower.contains('limit reached')) {
      return 'This coupon has reached its usage limit.';
    }
    if (lower.contains('already used') ||
        lower.contains('user_limit') ||
        lower.contains('maximum number')) {
      return 'You have already used this coupon.';
    }
    if (lower.contains('not found') ||
        lower.contains('invalid coupon') ||
        lower.contains('inactive')) {
      return 'This coupon is not available.';
    }
    if (lower.contains('not yet active') || lower.contains('not started')) {
      return 'This coupon is not yet active.';
    }
    if (lower.contains('multi-shop')) {
      return 'Coupons are not supported for orders from multiple stores.';
    }
    if (lower.contains('validation error')) {
      return 'Could not apply coupon. Please try again.';
    }
    return raw;
  }

  void clearError() {
    if (state.errorMessage == null) {
      return;
    }
    state = state.copyWith(errorMessage: null);
  }

  Future<CheckoutPlacementResult> placeOrder() async {
    // Prevent double-tap: if already placing, reject immediately
    if (state.isPlacingOrder) {
      return const CheckoutPlacementResult(
        errorMessage: 'Order already in progress.',
      );
    }

    final selectedPaymentMethod = state.paymentMethod;

    if (state.selectedAddress == null) {
      const message = 'Choose a delivery address to continue.';
      state = state.copyWith(errorMessage: message);
      return const CheckoutPlacementResult(errorMessage: message);
    }

    if (subtotal <= 0) {
      const message = 'Your cart is empty.';
      state = state.copyWith(errorMessage: message);
      return const CheckoutPlacementResult(errorMessage: message);
    }

    // A line can go out of stock (another customer buying the last unit)
    // while this screen is already open — the backend's validateCart()
    // would reject the whole order anyway (CHECKOUT_PARTIAL_FAIL), but with
    // a vague message that doesn't say which item. Catching it here first
    // gives a clear, actionable message instead of a wasted round trip.
    if (cart.items.any((item) => !item.hasEnoughStock)) {
      const message =
          'Remove the out-of-stock item(s) from your cart to continue.';
      state = state.copyWith(errorMessage: message);
      return const CheckoutPlacementResult(errorMessage: message);
    }

    // Final closed-store backstop: the schedule sheet already steers ASAP
    // selections away when the store is closed, but the store could have
    // closed in the gap between opening the sheet and tapping submit — the
    // backend enforces this too (STORE_CLOSED_ASAP_UNAVAILABLE), this just
    // avoids a round-trip failure for the common case.
    if (effectiveDeliverySlot.isAsap) {
      final storeOpen =
          ref.read(storeStatusProvider).asData?.value.isOpen ?? true;
      if (!storeOpen) {
        const message =
            'The store is currently closed. Please choose a scheduled delivery time.';
        state = state.copyWith(errorMessage: message);
        return const CheckoutPlacementResult(errorMessage: message);
      }
    }

    state = state.copyWith(isPlacingOrder: true, errorMessage: null);
    unawaited(
      ref.read(analyticsServiceProvider).logBeginCheckout(
            total,
            cart.itemCount,
          ),
    );

    final result = await ref.read(placeOrderUseCaseProvider).call(
          PlaceOrderParams(
            addressId: state.selectedAddress!.id,
            paymentMethod: selectedPaymentMethod.apiValue,
            couponCode: state.appliedCoupon?.code,
            deliveryMode: _resolvedDeliveryMode,
            scheduledDeliveryAt: _scheduledDeliveryAt,
            scheduledSlotStart: _scheduledSlotStart,
            scheduledSlotEnd: _scheduledSlotEnd,
            scheduledSlotLabel: _scheduledSlotLabel,
            quickDeliverySelected: effectiveDeliverySlot.quickDeliverySelected,
            useWallet: state.useWallet,
          ),
        );

    // IMPORTANT: dartz's fold() does NOT await async callbacks.
    // Extract the Either result synchronously, then run async logic after.
    if (result.isLeft()) {
      final failure =
          result.fold((l) => l, (_) => throw StateError('unreachable'));

      // The address shown as "selected" can go stale server-side (e.g. the
      // user deleted it and re-added one with the same label — a new row,
      // a new id) without this screen ever refetching the address list.
      // Left alone, selectedAddress keeps pointing at the dead id and every
      // retry fails identically with the same confusing "address not
      // found" toast next to a perfectly valid-looking address card. Clear
      // it and force a refresh so the next render falls back to the
      // current default/first address (or prompts to add one).
      if (failure.message.toLowerCase().contains('address not found')) {
        ref.read(addressProvider.notifier).refresh();
        state = state.copyWith(
          isPlacingOrder: false,
          errorMessage: failure.message,
          selectedAddress: null,
        );
        return CheckoutPlacementResult(errorMessage: failure.message);
      }

      state = state.copyWith(
        isPlacingOrder: false,
        errorMessage: failure.message,
      );
      return CheckoutPlacementResult(errorMessage: failure.message);
    }

    final order = result.fold((_) => throw StateError('unreachable'), (r) => r);
    // Cart invalidation moved to payment_provider.dart success paths only.
    // This prevents the blank-page-after-Razorpay-cancel bug.
    var handedOffToPayment = false;

    // A wallet-toggle order can arrive here already fully paid (the wallet
    // covered the entire total server-side) even though ONLINE was the
    // selected method — no Razorpay order was created for it, so it must
    // take the same "already done" path as COD below, not the Razorpay
    // handoff.
    final alreadyPaid = order.paymentStatus == 'PAID';

    if (selectedPaymentMethod == PaymentMethod.online && !alreadyPaid) {
      final paymentResult =
          await ref.read(paymentProvider.notifier).startRazorpayFlow(order);
      if (!paymentResult.isSuccess) {
        await _tryCancelOrder(
          order.id,
          reason: 'Payment gateway failed to launch',
        );
        state = state.copyWith(
          isPlacingOrder: false,
          errorMessage: paymentResult.errorMessage,
        );
        return CheckoutPlacementResult(
          errorMessage: paymentResult.errorMessage,
        );
      }
      // Razorpay is now open. Reset isPlacingOrder so checkout UI is usable
      // when Razorpay dismisses (cancel or success). The payment_provider
      // handles navigation on success.
      state = state.copyWith(isPlacingOrder: false);
      handedOffToPayment = true;
    }

    if (selectedPaymentMethod == PaymentMethod.cod || alreadyPaid) {
      // COD has no payment-gateway handoff, and an order the wallet already
      // fully paid has nothing left to hand off to either — clear the cart
      // and navigate to the order success screen ourselves, mirroring what
      // payment_provider does for online once its gateway confirms success.
      ref.invalidate(cartProvider);
      // Wallet balance is deducted server-side the instant the order is
      // placed (whenever useWallet was on, whether it covered the whole
      // total or just a slice of it) — without this, every wallet UI spot
      // (home pill, wallet screen, checkout toggle) kept showing the
      // pre-order balance until something unrelated (a topup, a manual
      // wallet-screen visit) happened to invalidate it.
      if (state.useWallet) {
        ref.invalidate(walletProvider);
      }
      resetForNewOrder();
      ref.read(appRouterProvider).go('/orders/success/${order.id}');
    }

    state = state.copyWith(
      isPlacingOrder: false,
      currentStep: CheckoutStep.review,
      errorMessage: null,
    );
    return CheckoutPlacementResult(
      order: order,
      handedOffToPayment: handedOffToPayment,
    );
  }

  Future<void> _tryCancelOrder(
    String orderId, {
    required String reason,
  }) async {
    try {
      final cancelResponse = await ref.read(dioClientProvider).post<dynamic>(
            ApiConstants.orderCancel(orderId),
            data: <String, dynamic>{'reason': reason},
          );
      if (_isPaymentConfirmedResponse(cancelResponse.data)) {
        _onPaymentConfirmedDuringCancel(orderId);
        return;
      }
      await ref.read(dioClientProvider).post<dynamic>(
        ApiConstants.orderReorder(orderId),
        data: const <String, dynamic>{},
      );
    } on DioException catch (error) {
      // The backend refuses to cancel (and confirms the order instead) when
      // its own live Razorpay check finds the payment was actually
      // captured — signalled by a 409 with `paymentConfirmed: true` in the
      // body. This call site only fires when the gateway itself failed to
      // even launch, so this is a narrow race, but it's the same class of
      // bug as _cancelPendingOrder in payment_provider.dart and worth the
      // same guard rather than discarding the response.
      if (_isPaymentConfirmedResponse(error.response?.data)) {
        _onPaymentConfirmedDuringCancel(orderId);
        return;
      }
      // If cancellation fails, keep the original payment failure visible.
    } catch (_) {
      // If cancellation fails, keep the original payment failure visible.
    }
  }

  bool _isPaymentConfirmedResponse(dynamic data) {
    return data is Map && data['paymentConfirmed'] == true;
  }

  void _onPaymentConfirmedDuringCancel(String orderId) {
    ref.invalidate(cartProvider);
    if (state.useWallet) {
      ref.invalidate(walletProvider);
    }
    resetForNewOrder();
    ref.read(appRouterProvider).go('/orders/success/$orderId');
  }

  CheckoutSummaryEntity get summary {
    return CheckoutSummaryEntity(
      subtotal: subtotal,
      discount: discount,
      deliveryFee: deliveryFee,
      platformFee: platformFee,
      total: total,
      itemCount: cart.itemCount,
    );
  }

  CartEntity get cart {
    final cartAsync = ref.read(cartProvider);
    return state.validatedCart?.cart ??
        switch (cartAsync) {
          AsyncData(:final value) => value,
          _ => CartEntity.empty(),
        };
  }

  double get subtotal => cart.subtotal;

  // A coupon can waive delivery independent of the subtotal threshold (see
  // CouponEntity.freeDelivery — either discountType FREE_DELIVERY or the
  // grantsFreeDelivery flag on any other discount type). Previously this
  // getter never read that flag at all, so an applied free-delivery coupon
  // showed no visible effect here even though the backend genuinely waives
  // the fee at order placement — this keeps the two in sync.
  double get deliveryFee => (state.appliedCoupon?.freeDelivery ?? false) ||
          subtotal >= AppConstants.freeDeliveryThreshold
      ? 0
      : AppConstants.standardDeliveryFee;

  double get discount {
    final amount = state.appliedCoupon?.discountAmount ?? 0;
    if (amount <= 0) {
      return 0;
    }
    return amount > subtotal ? subtotal : amount;
  }

  double get platformFee => cart.isEmpty ? 0 : AppConstants.platformFee;

  // This is a client-side estimate only (subtotal/discount/deliveryFee/
  // platformFee) — it knows nothing about handling/small-cart/surge/
  // packaging fees, GST, tip, quick-delivery surcharge, or an auto-applied
  // first-time-offer. Callers that need the real charge (e.g. the wallet
  // sufficiency check) must overlay the backend's billSummaryProvider total
  // themselves at the widget layer — see checkout_screen.dart's
  // `effectiveSummary`. This getter used to read billSummaryProvider
  // directly, but billSummaryProvider's own build() watches checkoutProvider
  // (for the applied-coupon override), so the two ended up in a mutual
  // dependency that Riverpod could flag as a CircularDependencyError.
  double get total {
    final value = subtotal - discount + deliveryFee + platformFee;
    return value < 0 ? 0 : value;
  }

  void _syncAddresses(List<AddressEntity> addresses) {
    if (addresses.isEmpty) {
      if (state.selectedAddress == null) {
        return;
      }
      state = state.copyWith(selectedAddress: null);
      return;
    }

    final current = state.selectedAddress;
    AddressEntity? selected;
    if (current != null) {
      AddressEntity? stillExists;
      for (final address in addresses) {
        if (address.id == current.id) {
          stillExists = address;
          break;
        }
      }
      if (stillExists != null) {
        // `current.isDefault` records what kind of selection this was, not
        // what the address looks like now: if it was the default at the
        // time it got selected (the common case — nobody explicitly picked
        // a different address for this cart), keep *tracking* the default
        // rather than freezing onto this one id forever. Reported bug: a
        // customer set a new default address elsewhere, but the cart/
        // checkout — and the address actually used to place the order —
        // kept silently using the old default, because it still existed in
        // the list and matched by id, so this loop never got as far as
        // re-resolving which address is default now.
        selected =
            current.isDefault ? _defaultAddress(addresses) : stillExists;
      }
    }

    selected ??= _defaultAddress(addresses);
    if (selected?.id == current?.id) {
      if (selected != current) {
        state = state.copyWith(selectedAddress: selected);
      }
      return;
    }

    state = state.copyWith(selectedAddress: selected);
  }

  void _syncCart(CartEntity nextCart) {
    final currentCoupon = state.appliedCoupon;
    var nextState = state.copyWith(
      validatedCart: CartValidationResult(
        valid: true,
        cart: nextCart,
      ),
    );

    if (currentCoupon != null &&
        nextCart.subtotal < currentCoupon.minOrderAmount) {
      nextState = nextState.copyWith(
        appliedCoupon: null,
        errorMessage:
            'Coupon removed because the cart total is below the minimum order amount.',
      );
    } else if (currentCoupon != null &&
        !_couponStillMatchesCart(currentCoupon, nextCart)) {
      // Reported bug: a coupon scoped to a specific product/category (e.g.
      // one vegetable item) stayed "applied" and kept discounting the bill
      // even after that item was removed and only out-of-scope items (e.g.
      // dairy) were left — nothing ever re-checked scope after the initial
      // apply. Every cart mutation already flows through here, so this is
      // the one place that needed the extra check.
      nextState = nextState.copyWith(
        appliedCoupon: null,
        errorMessage:
            'Coupon removed — it no longer applies to the items in your cart.',
      );
    }

    state = nextState;
  }

  /// True if [coupon] still applies to at least one line in [cart] — a
  /// coupon with no product/category scope on either list applies to the
  /// whole cart, so it always matches. Otherwise it's a hash-set membership
  /// check per cart line: O(items + scope size), purely local, no network
  /// or database call — this only ever re-derives from data the original
  /// /coupons/validate response already returned.
  bool _couponStillMatchesCart(CouponEntity coupon, CartEntity cart) {
    final productIds = coupon.applicableProductIds;
    final categoryIds = coupon.applicableCategoryIds;
    final hasProductScope = productIds != null && productIds.isNotEmpty;
    final hasCategoryScope = categoryIds != null && categoryIds.isNotEmpty;
    if (!hasProductScope && !hasCategoryScope) {
      return true;
    }

    final productIdSet =
        hasProductScope ? productIds.toSet() : const <String>{};
    final categoryIdSet =
        hasCategoryScope ? categoryIds.toSet() : const <String>{};

    return cart.items.any(
      (item) =>
          productIdSet.contains(item.productId) ||
          (item.categoryId != null && categoryIdSet.contains(item.categoryId)),
    );
  }

  AddressEntity? _defaultAddress(List<AddressEntity>? addresses) {
    if (addresses == null || addresses.isEmpty) {
      return null;
    }
    for (final address in addresses) {
      if (address.isDefault) {
        return address;
      }
    }
    return addresses.first;
  }

  // ── Delivery Slot Helpers ─────────────────────────────────────────────
  SelectedDeliverySlot get effectiveDeliverySlot =>
      state.selectedDeliverySlot ?? const SelectedDeliverySlot.asap();

  String get _resolvedDeliveryMode => effectiveDeliverySlot.mode;

  String? get _scheduledDeliveryAt {
    final slot = effectiveDeliverySlot;
    if (slot.isScheduled && slot.slot != null) {
      return slot.slot!.start.toUtc().toIso8601String();
    }
    return null;
  }

  String? get _scheduledSlotStart {
    final slot = effectiveDeliverySlot;
    if (slot.isScheduled && slot.slot != null) {
      return slot.slot!.start.toUtc().toIso8601String();
    }
    return null;
  }

  String? get _scheduledSlotEnd {
    final slot = effectiveDeliverySlot;
    if (slot.isScheduled && slot.slot != null) {
      return slot.slot!.end.toUtc().toIso8601String();
    }
    return null;
  }

  String? get _scheduledSlotLabel {
    final slot = effectiveDeliverySlot;
    if (slot.isScheduled) return slot.slotLabel;
    return null;
  }
}
