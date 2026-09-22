// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/bill_summary_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/savings_breakdown_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_enhancement_providers.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/core/providers/price_mode_provider.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/add_to_wishlist_prompt_sheet.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_bill_summary.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_checkout_dock.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_coupon_sheet.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_delivery_groups.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_first_time_offer_teaser.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_item_card.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_misc_widgets.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_offers_section.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_ordering_for.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_recommendations_section.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/schedule_delivery_sheet.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_savings_banner.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_tip_section.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/presentation/providers/purchase_limits_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/delivery_slot_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/delivery_slot_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/store_status_provider.dart';
import 'package:bakaloo_flutter_app/features/location/presentation/providers/non_serviceable_location_provider.dart';
import 'package:bakaloo_flutter_app/features/payments/presentation/providers/payment_provider.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:bakaloo_flutter_app/features/wishlist/presentation/providers/wishlist_ids_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/widgets/confirmation_dialog.dart';
import 'package:bakaloo_flutter_app/shared/widgets/empty_state.dart';
import 'package:bakaloo_flutter_app/shared/widgets/error_state.dart';

/// Cart screen — a compact review-and-adjust page. It shows what's in the
/// cart and lets the customer edit it (quantities, coupon, tip), AND places
/// the order directly: the sticky dock's two buttons (Cash on Delivery /
/// Pay Online) call `checkoutProvider.placeOrder()` right from here — no
/// separate Checkout page in this flow. Address is a compact display+edit
/// affordance in the dock only (no full address card in the scroll);
/// address completeness/serviceability is still enforced server-side at
/// placement. See cart_checkout_dock.dart.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      // which shows (and can toggle spending) the wallet balance.
      unawaited(ref.read(walletProvider.notifier).refreshWallet());
      // Address list can also change elsewhere (edited/deleted) — refresh
      // so the dock's selected address and placeOrder() never point at a
      // stale id (matches checkout_screen.dart's old behaviour, now that
      // this screen is the one actually placing the order).
      ref.read(addressProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Returning from a backgrounded UPI/wallet app is exactly when the
      // Razorpay SDK's own callback is most likely to have been lost — see
      // payment_provider.dart#recheckIfPending's own doc comment.
      ref.read(paymentProvider.notifier).recheckIfPending();
      unawaited(ref.read(walletProvider.notifier).refreshWallet());
    }
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
    // Watched (not just read) so the screen rebuilds the instant the wallet
    // toggle flips (CartOffersSection's switch lives in a sibling widget)
    // or a placement starts/finishes.
    final checkoutState = ref.watch(checkoutProvider);
    final paymentState = ref.watch(paymentProvider);

    ref
      ..listen<CheckoutState>(checkoutProvider, (prev, next) {
        final msg = next.errorMessage;
        if (msg != null && msg != prev?.errorMessage && mounted) {
          AppToast.show(context, msg);
          ref.read(checkoutProvider.notifier).clearError();
        }
      })
      ..listen<PaymentState>(paymentProvider, (prev, next) {
        final msg = next.errorMessage;
        if (msg != null && msg != prev?.errorMessage && mounted) {
          AppToast.show(context, msg);
          ref.read(paymentProvider.notifier).clearError();
        }
      });
    // Only meaningful while hasAddress is false — see
    // non_serviceable_location_provider.dart.
    final isLocationNotServiceable =
        !hasAddress && ref.watch(nonServiceableLocationProvider);
    final billSummaryAsync = ref.watch(billSummaryProvider);
    final billSummary = switch (billSummaryAsync) {
      AsyncData(:final value) => value,
      _ => null,
    };
    // AsyncValue.value keeps the last successfully-loaded summary visible
    // even while a new one is loading (e.g. after a quantity change),
    // unlike `billSummary` above which resets to null on every reload.
    //
    // Reported bug: the dock used to fall back to `cart.subtotal` (item
    // total only — no delivery/platform fee, no coupon/first-time-offer
    // discount) the instant `billSummary` went back to `AsyncLoading` on
    // ANY reload, so every quantity change flashed a wrong, lower total
    // before correcting itself once the backend responded — "price
    // fluctuates" from the customer's point of view. The backend's
    // TotalsEngine is the only source of truth for what a customer
    // actually owes; a client-computed guess must never be shown as if it
    // were that number. Now: show the last real backend total (still
    // accurate for the cart as it stood a moment ago) while a fresher one
    // loads, and only fall back to a genuine "calculating…" shimmer —
    // never a fabricated number — on the true first load, when there's no
    // real total yet at all.
    final lastKnownSummary = billSummaryAsync.value;
    final displayBillSummary = _displayBillSummary(
      cart: cart,
      remoteSummary: billSummary,
    );
    // `.value`, not `.asData?.value` — keeps showing the last known balance
    // while a refetch is in flight instead of flashing to ₹0.
    final walletBalance = ref.watch(walletProvider).value?.balance ?? 0.0;
    // walletApplied = min(availableWalletBalance, currentPayableAmount) —
    // the exact same rule the backend applies for real at order-creation
    // time (orders.service.js#placeOrder), so this preview can never
    // disagree with what actually gets charged/debited.
    final checkoutNotifier = ref.read(checkoutProvider.notifier);
    final walletApplied = checkoutNotifier.walletApplied;
    final payableAfterWallet = checkoutNotifier.payableAfterWallet;
    final codInfo = (lastKnownSummary ?? displayBillSummary).paymentMethods.cod;
    final onlineEnabled =
        (lastKnownSummary ?? displayBillSummary).paymentMethods.razorpay.enabled;
    final isPlacingOrder =
        checkoutState.isPlacingOrder || paymentState.isPendingConfirmation;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(context, cart.itemCount),
      body: Column(
        children: <Widget>[
          if (paymentState.isPendingConfirmation)
            _PendingConfirmationBanner(message: paymentState.pendingMessage),
          Expanded(
            child: cartAsync.when(
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

                // Piggybacks on the cart fetch that's already happening —
                // no extra per-line network call. Cheap no-op once already
                // known.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref
                      .read(purchaseLimitsNotifierProvider.notifier)
                      .ensureLoaded(
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
                    hasAddress: hasAddress,
                    billSummaryAsync: billSummaryAsync,
                    // Same "never show a fabricated number" rule as the
                    // dock's `payableAfterWallet`: prefer the last real
                    // backend total over the client-guessed fallback
                    // whenever one exists, so a reload (quantity change,
                    // coupon apply, etc.) keeps showing accurate figures
                    // instead of a stale-guess-then-jump.
                    billSummary: lastKnownSummary ?? displayBillSummary,
                    walletBalance: walletBalance,
                    walletApplied: walletApplied,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : CartCheckoutDock(
              hasAddress: hasAddress,
              selectedAddress: selectedAddress,
              isLocationNotServiceable: isLocationNotServiceable,
              toPay: payableAfterWallet,
              onAddAddress: () => _ensureAddressAndProceed(context),
              onEditAddress: () => _openAddressList(context),
              isPlacing: isPlacingOrder,
              codAvailable: codInfo.available,
              codUnavailableReason: codInfo.reason,
              onlineAvailable: onlineEnabled,
              onPlaceCod: () => _placeOrder(context, PaymentMethod.cod),
              onPlaceOnline: () => _placeOrder(context, PaymentMethod.online),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, int itemCount) {
    final mode = ref.watch(priceModeProvider);
    final modeLabel = mode == PriceMode.wholesale ? 'B2B' : 'B2C';
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
        '$modeLabel Cart${itemCount > 0 ? ' ($itemCount)' : ''}',
        style: TextStyle(
          fontSize: 18.sp,
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
    required bool hasAddress,
    required AsyncValue<BillSummaryEntity> billSummaryAsync,
    required BillSummaryEntity billSummary,
    required double walletBalance,
    required double walletApplied,
  }) {
    final savingsTotal = billSummary.savings.total;
    final estimateMinutes = billSummary.deliveryEstimate.minutes;
    final widgets = <Widget>[];

    if (savingsTotal > 0) {
      widgets.add(
        RepaintBoundary(
          child: CartSavingsBanner(savingsTotal: savingsTotal),
        ),
      );
    }

    widgets.add(
      RepaintBoundary(
        child: CartDeliveryGroupsHeading(
          deliveryCount: _deliveryGroupCount(cart.items, estimateMinutes),
        ),
      ),
    );
    widgets.addAll(
      _buildDeliveryGroups(
        context: context,
        items: cart.items,
        estimateMinutes: estimateMinutes,
      ),
    );
    widgets.add(SizedBox(height: 12.h));

    // Divider is bundled inside the section itself (not added here) since
    // whether it has anything to show is only known once the async
    // suggestions load — see CartRecommendationsSection.
    widgets.add(const RepaintBoundary(child: CartRecommendationsSection()));

    widgets.add(const RepaintBoundary(child: CartTipSection()));

    if (hasAddress) {
      widgets.add(const CartSectionDivider());
      widgets.add(const RepaintBoundary(child: CartOrderingFor()));
    }

    widgets.add(const CartSectionDivider());
    widgets.add(
      RepaintBoundary(
        child: CartOffersSection(
          onViewCoupons: () => showCartCouponSheet(context),
          showWalletTile: billSummary.paymentMethods.wallet.enabled,
          walletBalance: walletBalance,
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
          child: CartBillSummary(summary: billSummary, walletApplied: walletApplied),
        ),
        data: (_) => RepaintBoundary(
          child: CartBillSummary(summary: billSummary, walletApplied: walletApplied),
        ),
      ),
    );

    // Savings is now a compact expandable row inside CartBillSummary
    // itself, not a separate standalone card.
    widgets.add(const CartSectionDivider());
    widgets.add(const RepaintBoundary(child: CartPoliciesSection()));

    widgets.add(SizedBox(height: 100.h));

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
                padding: EdgeInsets.symmetric(horizontal: 14.w),
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

  /// The number of distinct delivery timings the cart's items actually
  /// split into — 1 for the overwhelming common case (everything ships on
  /// the cart's one real slot), 2 only when at least one item genuinely
  /// carries its own, distinctly longer estimate (see
  /// [_buildDeliveryGroups]'s `isLater` check, which this mirrors). Drives
  /// [CartDeliveryGroupsHeading]'s real, never-hardcoded count.
  int _deliveryGroupCount(List<CartItemEntity> items, int estimateMinutes) {
    final hasLaterItem = items.any((item) {
      final minutes = item.displayDeliveryMinutes;
      return minutes != null && minutes > estimateMinutes + 15;
    });
    return hasLaterItem ? 2 : 1;
  }

  /// Renders one [CartDeliveryGroupCard] PER cart item — never several
  /// items bundled under one shared box — each with its own "Delivering
  /// in X mins" header and "Change Slot" action, matching the reference
  /// exactly. All items on the cart's one real ASAP/Scheduled slot show
  /// the same timing label (they *are* on the same delivery); an item
  /// that genuinely carries its own, distinctly longer
  /// [CartItemEntity.displayDeliveryMinutes] than that shared estimate —
  /// real per-item data already returned by the backend, never a
  /// fabricated split — shows its own estimate instead and, since there's
  /// nothing to independently change for just that one item, no "Change
  /// Slot" chip.
  List<Widget> _buildDeliveryGroups({
    required BuildContext context,
    required List<CartItemEntity> items,
    required int estimateMinutes,
  }) {
    if (items.isEmpty) {
      return const <Widget>[];
    }

    final selectedSlot = ref.watch(
      checkoutProvider.select((s) => s.selectedDeliverySlot),
    );
    final effectiveSlot = selectedSlot ?? const SelectedDeliverySlot.asap();

    // Closed-store steering: when the store is closed and the customer
    // hasn't already picked a scheduled slot, swap the usual "X min
    // delivery" label for the next real available window instead — never
    // silently keep showing an ASAP estimate that can't be honored.
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

    return items.map((item) {
      final itemMinutes = item.displayDeliveryMinutes;
      final isLater = itemMinutes != null && itemMinutes > estimateMinutes + 15;

      return RepaintBoundary(
        child: CartDeliveryGroupCard.fromSlot(
          estimateMinutes: isLater ? itemMinutes : estimateMinutes,
          selectedSlot: isLater ? null : effectiveSlot,
          nextAvailableLabel: isLater ? null : nextAvailableLabel,
          onScheduleTap:
              isLater ? null : () => _openScheduleSheet(context),
          itemRows: _buildItemCards(context, <CartItemEntity>[item]),
        ),
      );
    }).toList(growable: false);
  }

  Future<void> _openScheduleSheet(BuildContext context) async {
    final alreadyScheduled = ref
        .read(checkoutProvider.select((s) => s.selectedDeliverySlot))
        ?.isScheduled ?? false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleDeliverySheet(initialScheduled: alreadyScheduled),
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

  /// "Add Address to Proceed" — just adds the address. No further
  /// auto-proceed step needed: once it's saved, `hasAddress` flips true and
  /// the dock re-renders into the two payment buttons on its own for the
  /// customer to tap.
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

  /// Places the order directly from the cart — Cash on Delivery or Pay
  /// Online, whichever button was tapped. Mirrors the old
  /// CheckoutScreen#_handlePayment: pick the method, wait for the real
  /// bill (never submit against a still-loading estimate), then delegate
  /// to CheckoutNotifier.placeOrder(), which validates the cart/address,
  /// applies the coupon + wallet, creates the order and — for ONLINE with
  /// money still owing — hands off to Razorpay.
  Future<void> _placeOrder(BuildContext context, PaymentMethod method) async {
    final currentState = ref.read(checkoutProvider);
    if (currentState.isPlacingOrder) {
      return;
    }

    if (currentState.selectedAddress == null) {
      AppToast.show(
        context,
        '📍 Please choose a delivery address first.',
        type: ToastType.warning,
      );
      return;
    }

    // Same guard checkout_screen.dart used to apply: never submit before
    // the real backend bill has loaded at least once, since every button
    // here displays that real total — a fast tap must never charge
    // something different from what was just shown.
    final billSummaryAsync = ref.read(billSummaryProvider);
    if (billSummaryAsync.isLoading && !billSummaryAsync.hasValue) {
      AppToast.show(
        context,
        'Calculating your final bill — please wait a moment.',
        type: ToastType.warning,
      );
      return;
    }

    ref.read(checkoutProvider.notifier).selectPaymentMethod(method);
    final result = await ref.read(checkoutProvider.notifier).placeOrder();

    if (!context.mounted) {
      return;
    }
    if (result.handedOffToPayment || result.isSuccess) {
      return;
    }
    if (result.errorMessage != null) {
      AppToast.show(context, result.errorMessage!);
    }
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

/// Shown while a Razorpay result is ambiguous and the app is asking the
/// backend to confirm it — see payment_provider.dart#_beginPendingConfirmation.
/// Never a dead-end error while this is up: the payment could still turn
/// out to have succeeded.
class _PendingConfirmationBanner extends StatelessWidget {
  const _PendingConfirmationBanner({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      color: const Color(0xFFFFF3E0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 18.w,
            height: 18.w,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFB45309),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              message ?? 'Verifying your payment…',
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFB45309),
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
