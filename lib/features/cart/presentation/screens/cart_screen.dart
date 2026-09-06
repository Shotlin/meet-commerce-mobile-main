// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/screens/add_edit_address_screen.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/bill_summary_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/savings_breakdown_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_enhancement_providers.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/add_to_wishlist_prompt_sheet.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_address_header.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_bill_summary.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_bottom_bar.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_coupons_offers.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_delivery_header.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_first_time_offer_teaser.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_item_card.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_misc_widgets.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_ordering_for.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_quick_add_section.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_savings_banner.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_savings_breakdown.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_tip_section.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/presentation/providers/purchase_limits_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/delivery_slot_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/delivery_slot_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/store_status_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/screens/coupons_screen.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/schedule_delivery_sheet.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/widgets/store_hours_sheet.dart';
import 'package:bakaloo_flutter_app/features/location/presentation/providers/non_serviceable_location_provider.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:bakaloo_flutter_app/features/wishlist/presentation/providers/wishlist_ids_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/widgets/confirmation_dialog.dart';
import 'package:bakaloo_flutter_app/shared/widgets/empty_state.dart';
import 'package:bakaloo_flutter_app/shared/widgets/error_state.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(priceDropProductsProvider);
      ref.read(paymentOffersProvider);
      // A line can go out of stock (another customer buying the last unit)
      // between when this customer added it and when they come back to
      // look at their cart — refresh on every visit so that shows up
      // promptly instead of only being discovered at a failed checkout.
      ref.read(cartProvider.notifier).refresh();
      // Same reasoning for wallet: a balance change made outside this app
      // (admin credit, refund, cashback) never invalidates the keepAlive
      // walletProvider on its own — refetch on every visit to this screen,
      // which shows (and can spend against) the wallet balance.
      unawaited(ref.read(walletProvider.notifier).refreshWallet());
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);
    final cart = switch (cartAsync) {
      AsyncData(:final value) => value,
      _ => CartEntity.empty(),
    };
    final selectedAddress = ref.watch(cartSelectedAddressProvider);
    final hasAddress = selectedAddress != null;
    // Only meaningful while hasAddress is false — see
    // non_serviceable_location_provider.dart.
    final isLocationNotServiceable =
        !hasAddress && ref.watch(nonServiceableLocationProvider);
    // House No./Building is no longer forced at app open (see
    // home_screen.dart's _maybeShowLocationPrompt) — an address that only
    // ever came from reverse geocoding can reach checkout with
    // addressLine2 still empty. This is the one place that actually needs
    // to block on it.
    final hasCompleteAddress = hasAddress &&
        (selectedAddress.addressLine2 ?? '').trim().isNotEmpty;
    final billSummaryAsync = ref.watch(billSummaryProvider);
    final billSummary = switch (billSummaryAsync) {
      AsyncData(:final value) => value,
      _ => null,
    };
    // AsyncValue.value keeps the last successfully-loaded summary visible
    // even while a new one is loading (e.g. after a quantity change),
    // unlike `billSummary` above which resets to null on every reload.
    // Used for both payment-method flags (rarely change mid-session, so no
    // reason to re-flash a loading state on every cart edit) and the "To
    // Pay" figure below.
    //
    // Reported bug: the bottom bar used to fall back to `cart.subtotal`
    // (item total only — no delivery/platform fee, no coupon/first-time-
    // offer discount) the instant `billSummary` went back to `AsyncLoading`
    // on ANY reload, so every quantity change flashed a wrong, lower total
    // before correcting itself once the backend responded — "price
    // fluctuates" from the customer's point of view. The backend's
    // TotalsEngine is the only source of truth for what a customer actually
    // owes; a client-computed guess must never be shown as if it were that
    // number. Now: show the last real backend total (still accurate for
    // the cart as it stood a moment ago) while a fresher one loads, and
    // only fall back to a genuine "calculating…" shimmer — never a
    // fabricated number — on the true first load, when there's no real
    // total yet at all.
    final lastKnownSummary = billSummaryAsync.value;
    final displayBillSummary = _displayBillSummary(
      cart: cart,
      remoteSummary: billSummary,
    );
    final summaryKnown = lastKnownSummary != null;
    final toPay = lastKnownSummary?.payable ?? displayBillSummary.payable;

    // Wallet-balance toggle — a pure client-side derivation from two values
    // already loaded here (walletProvider, billSummaryProvider), same
    // approach as the full checkout screen's equivalent calculation. The
    // actual charged amounts are independently and authoritatively computed
    // server-side at order-creation time regardless of what this preview
    // shows.
    final walletAsync = ref.watch(walletProvider);
    // `.value`, not `.asData?.value` — keeps showing the last known balance
    // while a refetch is in flight instead of flashing to ₹0 (`.asData` is
    // null during AsyncLoading even when it's carrying a previous value).
    final walletBalance = walletAsync.value?.balance ?? 0.0;
    final walletMethodEnabled =
        lastKnownSummary?.paymentMethods.wallet.enabled ??
            displayBillSummary.paymentMethods.wallet.enabled;
    // Shown even at zero balance (as long as the admin allows wallet at
    // all) — a customer who's never topped up otherwise never discovers
    // this option exists. `_WalletToggleStripe` itself swaps the switch for
    // an "Add Money" button whenever there's nothing to toggle on yet.
    final showWalletStripe = walletMethodEnabled;
    final canUseWallet = walletMethodEnabled && walletBalance > 0;
    final useWallet = ref.watch(
      checkoutProvider.select((s) => s.useWallet),
    );
    final walletApplied = (useWallet && canUseWallet)
        ? (walletBalance < toPay ? walletBalance : toPay)
        : 0.0;
    final remainderToPay = toPay - walletApplied < 0
        ? 0.0
        : toPay - walletApplied;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(context, cart.itemCount),
      body: cartAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFE23372)),
        ),
        error: (error, _) => ErrorState(
          message: error.toString().replaceFirst('Bad state: ', ''),
          onRetry: () => ref.read(cartProvider.notifier).refresh(),
        ),
        data: (resolvedCart) {
          if (resolvedCart.isEmpty) {
            return EmptyState(
              title: 'Your cart is empty',
              message: 'Add fresh groceries to start your order.',
              buttonLabel: 'Start Shopping',
              onPressed: () => context.go(RouteNames.home),
            );
          }

          // Piggybacks on the cart fetch that's already happening — no
          // extra per-line network call. Cheap no-op once already known.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(purchaseLimitsNotifierProvider.notifier).ensureLoaded(
                  resolvedCart.items.map((item) => item.productId).toList(),
                );
          });

          return ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            cacheExtent: 500,
            padding: EdgeInsets.zero,
            children: _buildSections(
              context: context,
              cart: resolvedCart,
              selectedAddress: selectedAddress,
              hasAddress: hasAddress,
              billSummaryAsync: billSummaryAsync,
              // Same "never show a fabricated number" rule as the bottom
              // bar's `toPay`: prefer the last real backend total over the
              // client-guessed fallback whenever one exists, so a reload
              // (quantity change, coupon apply, etc.) keeps showing
              // accurate figures instead of a stale-guess-then-jump.
              billSummary: lastKnownSummary ?? displayBillSummary,
            ),
          );
        },
      ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : CartBottomBar(
              hasAddress: hasAddress,
              hasCompleteAddress: hasCompleteAddress,
              isLocationNotServiceable: isLocationNotServiceable,
              toPay: remainderToPay,
              isPlacingOrder: ref.watch(
                checkoutProvider.select((s) => s.isPlacingOrder),
              ),
              // Whether the *real* summary (payment methods AND price) is
              // known yet. Until it is, the bar shows a loading placeholder
              // for both instead of a guess — see the comment above
              // `summaryKnown` for why a guess here caused two real bugs
              // (payment buttons flashing wrong, and "To Pay" fluctuating).
              paymentMethodsKnown: summaryKnown,
              onlineEnabled:
                  lastKnownSummary?.paymentMethods.razorpay.enabled ??
                      true,
              codEnabled:
                  lastKnownSummary?.paymentMethods.cod.enabled ??
                      true,
              showWalletToggle: showWalletStripe,
              walletBalance: walletBalance,
              walletApplied: walletApplied,
              orderTotal: toPay,
              useWallet: useWallet,
              onToggleWallet: (value) =>
                  ref.read(checkoutProvider.notifier).setUseWallet(value),
              onAddMoney: () => _goToTopup(
                context,
                suggestedAmount: toPay - walletBalance > 0
                    ? toPay - walletBalance
                    : null,
              ),
              onPayFullWallet: () => _handlePayFullWallet(
                context,
                codEnabled:
                    lastKnownSummary?.paymentMethods.cod.enabled ?? true,
              ),
              onAddAddress: () => _ensureAddressAndProceed(context),
              onCompleteAddress: selectedAddress == null
                  ? null
                  : () => _completeAddress(context, selectedAddress),
              onPayOnline: () => _handlePayOnline(context),
              onCod: () => _handleCod(context),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, int itemCount) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 16.w,
      // Explicit rather than relying on Flutter's automatic back button:
      // a notification deep link (e.g. CART_REMINDER, "your cart is
      // waiting") lands here via GoRouter's `.go()`, which REPLACES the
      // whole navigation stack rather than pushing on top of it — so Cart
      // can end up as the only route on the stack, with nothing to pop and
      // no back arrow at all. Reported bug: opening the cart from that
      // notification left no way back to the app. Home is always a safe,
      // sensible landing spot for that case; an ordinary in-app visit
      // (bottom nav, "See all", etc.) still just pops as before.
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: Color(0xFF222222),
        ),
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go(RouteNames.home);
          }
        },
      ),
      title: Text(
        'My Cart${itemCount > 0 ? ' ($itemCount)' : ''}',
        style: TextStyle(
          fontSize: 20.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF222222),
          fontFamily: 'Inter',
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
      ),
      actions: <Widget>[
        if (itemCount > 0)
          TextButton(
            onPressed: () => _clearCart(context),
            child: Text(
              'Clear',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE23372),
                fontFamily: 'Inter',
              ),
            ),
          ),
        SizedBox(width: 4.w),
      ],
    );
  }

  List<Widget> _buildSections({
    required BuildContext context,
    required CartEntity cart,
    required AddressEntity? selectedAddress,
    required bool hasAddress,
    required AsyncValue<BillSummaryEntity> billSummaryAsync,
    required BillSummaryEntity billSummary,
  }) {
    final savingsTotal = billSummary.savings.total;
    final estimateMinutes = billSummary.deliveryEstimate.minutes;
    final widgets = <Widget>[];

    if (hasAddress && selectedAddress != null) {
      widgets.add(
        RepaintBoundary(
          child: CartAddressHeader(
            address: selectedAddress,
            onTap: () => _openAddressList(context),
          ),
        ),
      );
    }

    if (savingsTotal > 0) {
      widgets.add(
        RepaintBoundary(
          child: CartSavingsBanner(savingsTotal: savingsTotal),
        ),
      );
    }

    widgets.add(
      RepaintBoundary(
        child: _buildDeliveryHeader(
          context: context,
          estimateMinutes: estimateMinutes,
          itemCount: cart.itemCount,
        ),
      ),
    );
    widgets.add(const CartSectionDivider());

    widgets.addAll(_buildItemCards(context, cart.items));
    widgets.add(const CartSectionDivider());

    // Divider is bundled inside the section itself (not added here) since
    // whether it has anything to show is only known once the async
    // suggestions load — see CartQuickAddSection.
    widgets.add(const RepaintBoundary(child: CartQuickAddSection()));

    widgets.add(const RepaintBoundary(child: CartTipSection()));

    if (hasAddress) {
      widgets.add(const CartSectionDivider());
      widgets.add(const RepaintBoundary(child: CartOrderingFor()));
      widgets.add(const CartSectionDivider());
      widgets.add(const RepaintBoundary(child: CartCancellationPolicy()));
    }

    widgets.add(const CartSectionDivider());
    widgets.add(
      RepaintBoundary(
        child: CartCouponsOffers(
          onViewCoupons: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const CouponsScreen(),
              ),
            );
          },
        ),
      ),
    );
    widgets.add(const CartSectionDivider());

    if (billSummary.firstTimeOfferTeaser != null) {
      widgets.add(
        RepaintBoundary(
          child: CartFirstTimeOfferTeaser(
            teaser: billSummary.firstTimeOfferTeaser!,
          ),
        ),
      );
      widgets.add(const CartSectionDivider());
    }

    widgets.add(
      billSummaryAsync.when(
        // Without this, .when() shows `loading` on every reload by
        // default (any quantity change, coupon apply, etc.), re-shimmering
        // a breakdown that's already accurate and just being refreshed —
        // `billSummary` here is now the last-known-good total (see the
        // call site), so there's real, correct data to keep showing while
        // the fresher one loads. Only a genuine first load (no previous
        // value at all) still shows the shimmer.
        skipLoadingOnReload: true,
        loading: () => RepaintBoundary(child: _buildBillSummaryShimmer()),
        error: (_, __) => RepaintBoundary(
          child: CartBillSummary(summary: billSummary),
        ),
        data: (_) => RepaintBoundary(
          child: CartBillSummary(summary: billSummary),
        ),
      ),
    );

    if (billSummary.savings.total > 0) {
      widgets.add(const CartSectionDivider());
      widgets.add(
        RepaintBoundary(
          child: CartSavingsBreakdown(savings: billSummary.savings),
        ),
      );
    }

    widgets.add(SizedBox(height: 110.h));

    return widgets;
  }

  List<Widget> _buildItemCards(
    BuildContext context,
    List<CartItemEntity> items,
  ) {
    return List<Widget>.generate(items.length, (index) {
      final item = items[index];
      // Purchase-limits: null == unrestricted (the common case, zero extra
      // visual/logic changes). Watched so this line live-updates — e.g.
      // right after this exact tap pushes the product to its limit.
      final purchaseLimitStatus =
          ref.watch(purchaseLimitStatusProvider(item.productId));
      final isAtLimit = purchaseLimitStatus?.isAtLimit ?? false;

      return RepaintBoundary(
        child: Column(
          children: <Widget>[
            CartItemCard(
              item: item,
              onIncrease: () {
                // Re-checked fresh on every tap (ref.read, not the watched
                // value above) so a stale cache can never let a mutation
                // through — block before it ever reaches the network.
                final status =
                    ref.read(purchaseLimitStatusProvider(item.productId));
                if (status?.isAtLimit ?? false) {
                  AppToast.show(context, 'Maximum product order complete');
                  return;
                }
                // Re-checked fresh for the same reason as the purchase-limit
                // guard above — a line can go out of stock (another
                // customer buying the last unit) while this screen is
                // already open, and the "+" must never push past what's
                // actually left.
                if (!item.hasEnoughStock) {
                  AppToast.show(
                    context,
                    item.stockQuantity <= 0
                        ? 'This item is out of stock'
                        : 'Only ${item.stockQuantity} left in stock',
                  );
                  return;
                }
                _updateItemQuantity(
                  context,
                  item.productId,
                  item.quantity + 1,
                  shopProductId: item.shopProductId,
                );
              },
              onDecrease: () {
                if (item.quantity <= 1) {
                  _removeItem(context, item);
                  return;
                }
                _updateItemQuantity(
                  context,
                  item.productId,
                  item.quantity - 1,
                  shopProductId: item.shopProductId,
                );
              },
              onRemove: () => _removeItem(context, item),
              disableIncrease: isAtLimit || !item.hasEnoughStock,
            ),
            if (index != items.length - 1)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF0F0F0),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildBillSummaryShimmer() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: List<Widget>.generate(
            5,
            (index) => Padding(
              padding: EdgeInsets.only(bottom: index == 4 ? 0 : 14.h),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      height: 12.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Container(
                    width: 64.w,
                    height: 12.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryHeader({
    required BuildContext context,
    required int estimateMinutes,
    required int itemCount,
  }) {
    final selectedSlot = ref.watch(
      checkoutProvider.select((s) => s.selectedDeliverySlot),
    );
    final effectiveSlot = selectedSlot ?? const SelectedDeliverySlot.asap();

    // Closed-store steering: when the store is closed and the customer
    // hasn't already picked a scheduled slot, swap the usual "X min
    // delivery" header for the next real available window instead —
    // never silently keep showing an ASAP estimate that can't be honored.
    final storeOpen =
        ref.watch(storeStatusProvider).asData?.value.isOpen ?? true;
    String? nextAvailableLabel;
    if (!storeOpen && effectiveSlot.isAsap) {
      final days = ref.watch(deliverySlotsProvider).asData?.value ?? const [];
      for (final day in days) {
        final availableSlots = day.slots.where((s) => s.available);
        if (availableSlots.isNotEmpty) {
          nextAvailableLabel = '${day.label}, ${availableSlots.first.label}';
          break;
        }
      }
    }

    return CartDeliveryHeader(
      estimateMinutes: estimateMinutes,
      itemCount: itemCount,
      selectedSlot: effectiveSlot,
      nextAvailableLabel: nextAvailableLabel,
      onScheduleTap: () => _openScheduleSheet(context, initialScheduled: true),
      onExpressTap: () => _openScheduleSheet(context, initialScheduled: false),
      onViewHoursTap: () => StoreHoursSheet.show(context),
    );
  }

  Future<void> _openScheduleSheet(
    BuildContext context, {
    required bool initialScheduled,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleDeliverySheet(initialScheduled: initialScheduled),
    );
  }

  Future<void> _clearCart(BuildContext context) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Clear cart?',
      message: 'This will remove all items from your cart.',
      confirmLabel: 'Clear',
    );

    if (confirmed != true || !mounted) {
      return;
    }

    // Snapshot before clearing — CartNotifier.clearCart() sets state to
    // CartEntity.empty() synchronously, so the item list is gone by the
    // time this call resolves.
    final clearedItems = switch (ref.read(cartProvider)) {
      AsyncData(:final value) => value.items,
      _ => const <CartItemEntity>[],
    };

    final result = await ref.read(cartProvider.notifier).clearCart();
    if (!context.mounted) {
      return;
    }
    if (!result.isSuccess) {
      showCartSnackBar(context, result.failure!.message);
      return;
    }

    // Reset delivery slot to ASAP when cart is cleared
    ref.read(checkoutProvider.notifier).clearDeliverySlot();

    final wishlistIds = ref.read(wishlistIdsProvider);
    final notWishlisted = clearedItems
        .where((item) => !wishlistIds.contains(item.productId))
        .toList(growable: false);
    if (notWishlisted.isNotEmpty) {
      await showAddToWishlistPrompt(context, items: notWishlisted);
    }
  }

  Future<bool> _openAddAddress(BuildContext context) async {
    final changed = await context.push<bool>(RouteNames.addAddress);
    if (!context.mounted || changed != true) {
      return false;
    }

    ref.read(addressProvider.notifier).refresh();
    try {
      await ref.read(addressProvider.future);
    } catch (_) {}
    return true;
  }

  /// "Complete Your Address" button — opens the same forced completion
  /// screen home_screen.dart used to push automatically on every app open
  /// (see _maybeShowLocationPrompt there for why that was removed); this is
  /// the checkout-time equivalent, only reached when the customer actually
  /// tries to order with House No./Building still missing.
  Future<void> _completeAddress(
    BuildContext context,
    AddressEntity address,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AddEditAddressScreen(
          initialAddress: address,
          forceCompletion: true,
        ),
      ),
    );
    if (!context.mounted) {
      return;
    }
    ref.read(addressProvider.notifier).refresh();
    try {
      await ref.read(addressProvider.future);
    } catch (_) {}
  }

  /// "Add Address to Proceed" button — just adds the address. No further
  /// auto-proceed step needed: once it's saved, `hasAddress` flips true and
  /// the bottom bar re-renders into the Pay Online / Cash-Wallet buttons on
  /// its own for the customer to tap.
  Future<void> _ensureAddressAndProceed(BuildContext context) async {
    await _openAddAddress(context);
  }

  Future<void> _openAddressList(BuildContext context) async {
    await context.push(RouteNames.addresses);
    if (!mounted) {
      return;
    }

    ref.read(addressProvider.notifier).refresh();
  }

  Future<void> _removeItem(BuildContext context, CartItemEntity item) async {
    final result = await ref.read(cartProvider.notifier).removeItem(
          item.productId,
          shopProductId: item.shopProductId,
        );
    if (!context.mounted) {
      return;
    }
    if (!result.isSuccess) {
      showCartSnackBar(context, result.failure!.message);
      return;
    }

    final alreadyWishlisted =
        ref.read(wishlistIdsProvider).contains(item.productId);
    if (!alreadyWishlisted) {
      await showAddToWishlistPrompt(context, items: <CartItemEntity>[item]);
    }
  }

  Future<void> _updateItemQuantity(
    BuildContext context,
    String productId,
    int quantity, {
    String? shopProductId,
  }) async {
    final result = await ref.read(cartProvider.notifier).updateItem(
          productId,
          quantity,
          shopProductId: shopProductId,
        );
    if (!result.isSuccess && context.mounted) {
      showCartSnackBar(context, result.failure!.message);
    }
  }

  /// Shared pre-flight for both payment buttons: resolves the selected
  /// address (prompting for one if missing, or completing it if it's still
  /// missing House No./Building — see CartBottomBar's hasCompleteAddress)
  /// and re-validates the cart against the live backend (stock/pricing may
  /// have moved since this screen opened) — the same two checks
  /// `_proceedToCheckout` used to run before handing off to the separate
  /// checkout page. Returns the address to place the order against, or null
  /// if the caller should stop (an error was already surfaced, or the user
  /// backed out of adding/completing one). Defense-in-depth alongside the
  /// bottom bar's own gating — the buttons this guards are only ever
  /// reachable once the bar shows them at all, but this makes the guarantee
  /// hold regardless of how that ever changes.
  Future<AddressEntity?> _validateForPayment(BuildContext context) async {
    var selectedAddress = ref.read(cartSelectedAddressProvider);
    if (selectedAddress == null) {
      final added = await _openAddAddress(context);
      if (!context.mounted || !added) {
        return null;
      }
      selectedAddress = ref.read(cartSelectedAddressProvider);
      if (selectedAddress == null) {
        return null;
      }
    }

    if ((selectedAddress.addressLine2 ?? '').trim().isEmpty) {
      await _completeAddress(context, selectedAddress);
      if (!context.mounted) {
        return null;
      }
      final completedAddress = ref.read(cartSelectedAddressProvider);
      if (completedAddress == null ||
          (completedAddress.addressLine2 ?? '').trim().isEmpty) {
        return null;
      }
      selectedAddress = completedAddress;
    }

    final validation =
        await ref.read(cartProvider.notifier).validateAndProceed();
    if (!context.mounted) {
      return null;
    }
    if (validation.hasFailure) {
      showCartSnackBar(context, validation.failure!.message);
      return null;
    }
    if (!validation.valid) {
      showCartSnackBar(context, validation.warnings.join('\n'));
      return null;
    }

    return selectedAddress;
  }

  /// Places the order for [method] and surfaces any failure. Success needs
  /// no handling here: COD navigates to the order-success screen and
  /// online/wallet hand off to their own payment flow, all already inside
  /// CheckoutNotifier.placeOrder().
  Future<void> _placeOrder(BuildContext context, PaymentMethod method) async {
    final checkoutNotifier = ref.read(checkoutProvider.notifier);
    checkoutNotifier.selectPaymentMethod(method);
    final result = await checkoutNotifier.placeOrder();

    if (!context.mounted) {
      return;
    }
    if (result.errorMessage != null) {
      showCartSnackBar(context, result.errorMessage!);
    }
  }

  Future<void> _handlePayOnline(BuildContext context) async {
    if (ref.read(checkoutProvider).isPlacingOrder) {
      return;
    }
    final address = await _validateForPayment(context);
    if (address == null || !context.mounted) {
      return;
    }
    ref.read(checkoutProvider.notifier).selectAddress(address);
    await _placeOrder(context, PaymentMethod.online);
  }

  /// "Cash on Delivery" — wallet is no longer a separate exclusive method
  /// here; it's the orthogonal toggle in [CartBottomBar] (see
  /// `useWallet`/`onToggleWallet` wiring in `build()`), which offsets the
  /// total regardless of which button is tapped. This handler just places
  /// the order as COD — whatever the toggle is currently set to travels
  /// with it via `checkoutProvider`'s own state.
  Future<void> _handleCod(BuildContext context) async {
    if (ref.read(checkoutProvider).isPlacingOrder) {
      return;
    }
    final address = await _validateForPayment(context);
    if (address == null || !context.mounted) {
      return;
    }
    ref.read(checkoutProvider.notifier).selectAddress(address);
    await _placeOrder(context, PaymentMethod.cod);
  }

  /// Opens wallet top-up from the cart's "Add Money" button — pre-filled
  /// with the shortfall so the customer doesn't have to work out how much
  /// more they need — and refreshes the balance on return. The customer may
  /// have topped up even if they didn't pop with `true`, so always refresh
  /// rather than trusting the pop result.
  Future<void> _goToTopup(BuildContext context, {double? suggestedAmount}) async {
    await context.push<bool>(
      RouteNames.topup,
      extra: suggestedAmount,
    );
    if (!context.mounted) {
      return;
    }
    ref.invalidate(walletProvider);
  }

  /// "Pay via Wallet" — the wallet stripe's dedicated one-tap action once
  /// the balance already covers the order in full. Reuses the same
  /// placeOrder path as COD/Online (useWallet is already true by the time
  /// this button is visible); the nominal method just needs to be one the
  /// admin actually has enabled, since the backend's payment-method gate
  /// checks that regardless of the wallet fully covering the remainder.
  Future<void> _handlePayFullWallet(
    BuildContext context, {
    required bool codEnabled,
  }) async {
    if (ref.read(checkoutProvider).isPlacingOrder) {
      return;
    }
    final address = await _validateForPayment(context);
    if (address == null || !context.mounted) {
      return;
    }
    ref.read(checkoutProvider.notifier)
      ..selectAddress(address)
      // The "Pay with Wallet" button is reachable without the switch ever
      // having been toggled on (it only shows when balance already covers
      // the order) — set this explicitly rather than assuming it's already
      // true.
      ..setUseWallet(true);
    await _placeOrder(
      context,
      codEnabled ? PaymentMethod.cod : PaymentMethod.online,
    );
  }

  BillSummaryEntity _displayBillSummary({
    required CartEntity cart,
    required BillSummaryEntity? remoteSummary,
  }) {
    // The backend TotalsEngine is the single source of truth — when its
    // summary is available we render it verbatim (dynamic delivery fee,
    // handling/platform fees, distance, free-delivery progress, total).
    if (remoteSummary != null) {
      return remoteSummary;
    }

    // Fallback shown only while the backend summary is still loading: show the
    // item subtotal without fabricating any fees (no hardcoded ₹25/₹5 math).
    final mrpSavings = cart.totalSavings;
    return BillSummaryEntity(
      itemTotal: ItemTotal(
        original: cart.subtotal + mrpSavings,
        discounted: cart.subtotal,
      ),
      deliveryFee: const DeliveryFeeInfo(),
      handlingFee: const FeeInfo(),
      lateNightFee: const LateNightFeeInfo(),
      toPay: BillToPay(
        original: cart.subtotal + mrpSavings,
        finalAmount: cart.subtotal,
      ),
      savings: SavingsBreakdownEntity(
        total: mrpSavings,
        items: <SavingsLineItem>[
          if (mrpSavings > 0)
            SavingsLineItem(
              type: 'mrp_discount',
              label: 'Discount on MRP',
              amount: mrpSavings,
            ),
        ],
      ),
      deliveryEstimate: const DeliveryEstimate(),
      totalPayable: cart.subtotal,
      tipAmount: cart.tipAmount,
      itemCount: cart.itemCount,
    );
  }
}
