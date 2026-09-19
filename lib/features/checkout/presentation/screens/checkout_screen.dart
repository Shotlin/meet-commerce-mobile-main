import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/providers/price_mode_provider.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/bill_summary_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_enhancement_providers.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/schedule_delivery_sheet.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/widgets/store_hours_sheet.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/checkout_summary_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/delivery_slot_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:bakaloo_flutter_app/features/payments/presentation/providers/payment_provider.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CheckoutScreen — Payment-only page: Wallet + Razorpay Online
// ═══════════════════════════════════════════════════════════════════════════

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen>
    with WidgetsBindingObserver {
  bool _billExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Refresh wallet balance every time checkout opens — this is the
    // screen that decides how much wallet gets applied to the order, so it
    // must never show a value stale enough to promise more than the
    // customer actually has. A plain `.future` read only warms the
    // keepAlive provider the first time; it wouldn't refetch a balance that
    // changed server-side (admin credit, refund, cashback) since it was
    // last built this session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(ref.read(walletProvider.notifier).refreshWallet());
      }
    });
    // Refresh the address list every time checkout opens. addressProvider
    // is keepAlive and only refetches on explicit invalidation, so an
    // address deleted/recreated (or edited) elsewhere since the last fetch
    // — including in a different app session — would otherwise leave
    // CheckoutNotifier's selectedAddress pointing at a stale id that looks
    // fine on screen but fails with "Delivery address not found" the
    // moment the order is placed.
    ref.read(addressProvider.notifier).refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Refresh cart when leaving checkout (back press, payment cancel, etc.)
    // so that any Redis mutations from validateCart are reflected in the
    // Flutter cart state. This prevents "Item not in cart" on the next
    // cart screen interaction.
    ref.read(cartProvider.notifier).refresh();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Returning from a backgrounded UPI/wallet app is exactly when the
      // Razorpay SDK's own callback is most likely to have been lost (the
      // OS reclaiming the activity while the UPI app had control) — check
      // with the backend immediately rather than waiting for the poll's
      // own next scheduled tick, or leaving the customer stuck if no poll
      // ever started (e.g. onExternalWallet with the app then killed).
      ref.read(paymentProvider.notifier).recheckIfPending();
      // The wallet balance itself can also have changed while backgrounded
      // (a topup approved, a refund landed) — refresh it too.
      unawaited(ref.read(walletProvider.notifier).refreshWallet());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);
    final checkoutState = ref.watch(checkoutProvider);
    // FIX: Use walletProvider (WalletNotifier, keepAlive) instead of the
    // separate walletBalanceProvider so balance is always available from the
    // already-loaded WalletEntity — prevents "Balance unavailable" error state.
    final walletAsync = ref.watch(walletProvider);
    // `.value`, not `.asData?.value` — keeps showing the last known balance
    // while a refetch is in flight instead of flashing to ₹0 (`.asData` is
    // null during AsyncLoading even when it's carrying a previous value).
    final walletBalance = walletAsync.value?.balance;
    final walletLoading = walletAsync.isLoading;
    final summary = ref.read(checkoutProvider.notifier).summary;
    // Backend bill summary is the source of truth for the amount charged.
    // Use it for every money display + the wallet offset calculation so the
    // checkout total always matches what the backend actually charges.
    final billSummaryAsync = ref.watch(billSummaryProvider);
    final billSummary = billSummaryAsync.asData?.value;
    final billSummaryLoading =
        billSummaryAsync.isLoading && billSummary == null;
    final rawPayable = billSummary?.payable ?? summary.total;
    // Wallet-balance toggle — a pure client-side derivation from two values
    // already loaded here (walletProvider, billSummaryProvider), never a
    // second server round-trip. The actual charged amounts are
    // independently and authoritatively computed server-side at
    // order-creation time regardless of what this preview shows — the same
    // relationship that already exists between rawPayable and the real
    // order total.
    final walletMethodEnabled =
        billSummary?.paymentMethods.wallet.enabled ?? false;
    // Shown even at zero balance (as long as the admin allows wallet at
    // all) — a customer who's never topped up otherwise never discovers
    // this option exists. `_WalletToggleRow` swaps the switch for an "Add
    // Money" button whenever there's nothing to toggle on yet.
    final showWalletToggle = walletMethodEnabled;
    final canUseWallet = walletMethodEnabled && (walletBalance ?? 0) > 0;
    final walletApplied = (checkoutState.useWallet && canUseWallet)
        ? ((walletBalance ?? 0.0) < rawPayable ? walletBalance! : rawPayable)
        : 0.0;
    final remainderPayable =
        rawPayable - walletApplied < 0 ? 0.0 : rawPayable - walletApplied;
    final effectiveSummary = summary.copyWith(total: remainderPayable);
    final isPlacing = checkoutState.isPlacingOrder;
    final paymentState = ref.watch(paymentProvider);

    ref
      // ── Listen for checkout errors ────────────────────────────────────
      ..listen<CheckoutState>(checkoutProvider, (prev, next) {
        final msg = next.errorMessage;
        if (msg != null && msg != prev?.errorMessage && mounted) {
          AppToast.show(context, msg);
          ref.read(checkoutProvider.notifier).clearError();
        }
      })
      // ── Listen for payment errors (Razorpay cancel / failure) ─────────
      ..listen<PaymentState>(paymentProvider, (prev, next) {
        final msg = next.errorMessage;
        if (msg != null && msg != prev?.errorMessage && mounted) {
          AppToast.show(context, msg);
          ref.read(paymentProvider.notifier).clearError();
        }
      });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: _buildAppBar(checkoutState),
      body: Column(
        children: [
          if (paymentState.isPendingConfirmation)
            _PendingConfirmationBanner(message: paymentState.pendingMessage),
          Expanded(
            child: cartAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              ),
              error: (error, _) => _EmptyState(
                message: error.toString().replaceFirst('Bad state: ', ''),
              ),
              data: (cart) {
                if (cart.isEmpty) {
                  return const _EmptyState(message: 'Your cart is empty.');
                }
                return _buildBody(
                  checkoutState: checkoutState,
                  summary: effectiveSummary,
                  billSummary: billSummary,
                  billSummaryLoading: billSummaryLoading,
                  itemCount: cart.itemCount,
                  items: cart.items,
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _CheckoutBottomBar(
        summary: effectiveSummary,
        // Also spins/disables the CTA while the real bill is still loading
        // (see the matching guard in _handlePayment) — shows the customer
        // why the button is briefly unavailable instead of a dead tap.
        isLoading: isPlacing ||
            paymentState.isPendingConfirmation ||
            billSummaryLoading,
        onPlaceOrder: () => _handlePayment(checkoutState.paymentMethod),
        showWalletToggle: showWalletToggle,
        walletBalance: walletBalance ?? 0.0,
        walletLoading: walletLoading,
        useWallet: checkoutState.useWallet,
        walletApplied: walletApplied,
        orderTotal: rawPayable,
        onToggleWallet: (value) =>
            ref.read(checkoutProvider.notifier).setUseWallet(value),
        onAddMoney: () => _goToTopup(
          context,
          suggestedAmount: rawPayable - (walletBalance ?? 0.0) > 0
              ? rawPayable - (walletBalance ?? 0.0)
              : null,
        ),
        onPayFullWallet: () => _handlePayFullWallet(
          context,
          codEnabled: billSummary?.paymentMethods.cod.enabled ?? true,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(CheckoutState state) {
    final address = state.selectedAddress;
    final mode = ref.watch(priceModeProvider);
    final modeLabel = mode == PriceMode.wholesale ? 'B2B' : 'B2C';
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('$modeLabel Order · Payment Options', style: AppTextStyles.h3),
          if (address != null)
            Text(
              'Delivering to ${address.label}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11.sp,
              ),
            ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.divider),
      ),
    );
  }

  Widget _buildBody({
    required CheckoutState checkoutState,
    required CheckoutSummaryEntity summary,
    required BillSummaryEntity? billSummary,
    required bool billSummaryLoading,
    required int itemCount,
    required List<CartItemEntity> items,
  }) {
    final address = checkoutState.selectedAddress;
    final selectedMethod = checkoutState.paymentMethod;
    final paymentMethods =
        billSummary?.paymentMethods ?? const PaymentMethodsInfo();
    final cod = paymentMethods.cod;

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 100.h),
      children: <Widget>[
        // ── Order Items Review (option labels visible) ──────────────
        _OrderItemsReviewCard(items: items),

        Gap(12.h),

        // ── Bill Accordion ──────────────────────────────────────────
        _BillAccordion(
          summary: summary,
          billSummary: billSummary,
          billSummaryLoading: billSummaryLoading,
          expanded: _billExpanded,
          onToggle: () => setState(() => _billExpanded = !_billExpanded),
        ),

        Gap(12.h),

        // ── Delivery Info ───────────────────────────────────────────
        if (address != null)
          _DeliveryInfoCard(
            address: address,
            itemCount: itemCount,
            selectedSlot: checkoutState.selectedDeliverySlot,
            onChangeAddress: () => _changeAddress(context),
            onChangeSlot: () => _openScheduleSheet(context),
            onViewHoursTap: () => StoreHoursSheet.show(context),
          )
        else
          _AddAddressCard(onTap: () => _changeAddress(context)),

        Gap(24.h),

        // ── Section Label ───────────────────────────────────────────
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
          child: Text(
            'CHOOSE PAYMENT',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.orderViolet,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              fontSize: 11.sp,
            ),
          ),
        ),

        // ── Cash on Delivery Card ────────────────────────────────────
        _CodPaymentCard(
          total: summary.total,
          available: cod.available,
          reason: cod.reason,
          selected: selectedMethod == PaymentMethod.cod,
          onSelect: () => ref
              .read(checkoutProvider.notifier)
              .selectPaymentMethod(PaymentMethod.cod),
          onPlaceOrder: () => _handlePayment(PaymentMethod.cod),
          isPlacingOrder: checkoutState.paymentMethod == PaymentMethod.cod &&
              checkoutState.isPlacingOrder,
        ),

        Gap(12.h),

        // ── Razorpay Card — hidden entirely when the admin disables it ─
        if (paymentMethods.razorpay.enabled)
          _RazorpayPaymentCard(
            total: summary.total,
            selected: selectedMethod == PaymentMethod.online,
            onSelect: () => ref
                .read(checkoutProvider.notifier)
                .selectPaymentMethod(PaymentMethod.online),
            onPay: () => _handlePayment(PaymentMethod.online),
            isPlacingOrder:
                checkoutState.paymentMethod == PaymentMethod.online &&
                    checkoutState.isPlacingOrder,
          ),

        Gap(18.h),

        // ── Footer Info ─────────────────────────────────────────────
        const _SecurePaymentBadge(),

        Gap(16.h),

        const _CheckoutFooter(),
      ],
    );
  }

  // ── Payment Handler ─────────────────────────────────────────────────
  Future<void> _handlePayment(PaymentMethod method) async {
    final currentState = ref.read(checkoutProvider);
    if (currentState.isPlacingOrder) {
      return;
    }

    if (currentState.selectedAddress == null) {
      AppToast.show(context, '📍 Please choose a delivery address first.',
          type: ToastType.warning);
      return;
    }

    // BUG FIX: every payment card (bottom bar, COD card, Razorpay card, and
    // the wallet "Pay Full" shortcut) funnels into this one method, but none
    // of their buttons were gated on `billSummaryLoading` — only on
    // `isPlacingOrder`. Until the real bill summary loads, `summary.total`
    // (what every card displays) is `checkoutProvider`'s own crude estimate
    // — subtotal minus discount plus a flat delivery+platform fee only, with
    // no GST, handling/small-cart/surge fee, or auto-applied first-time-
    // offer/cart-milestone discount. The backend always computes the actual
    // charge fresh at order-creation time regardless of what was shown, so
    // a fast tap here never over/under-charges — but it does let the
    // customer submit before ever seeing the real number, then get charged
    // something different from what was on screen a moment earlier: exactly
    // the "sometimes right, sometimes wrong" total pattern reported. Block
    // submission until billSummaryProvider has resolved at least once.
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

    if (!mounted) {
      return;
    }
    if (result.handedOffToPayment) {
      return;
    }
    if (result.isSuccess) {
      return;
    }

    if (result.errorMessage != null) {
      AppToast.show(context, result.errorMessage!);
    }
  }

  /// "Pay via Wallet" — the wallet row's dedicated one-tap action once the
  /// balance already covers the order in full. Reuses `_handlePayment`
  /// (useWallet is already true by the time this button is visible); the
  /// nominal method just needs to be one the admin actually has enabled,
  /// since the backend's payment-method gate checks that regardless of the
  /// wallet fully covering the remainder.
  Future<void> _handlePayFullWallet(
    BuildContext context, {
    required bool codEnabled,
  }) {
    // The "Pay with Wallet" button is reachable without the switch ever
    // having been toggled on (it only shows when balance already covers
    // the order) — set this explicitly rather than assuming it's already
    // true.
    ref.read(checkoutProvider.notifier).setUseWallet(true);
    return _handlePayment(
        codEnabled ? PaymentMethod.cod : PaymentMethod.online);
  }

  // ── Address Change ──────────────────────────────────────────────────
  Future<void> _changeAddress(BuildContext context) async {
    final addressAsync = ref.read(addressProvider);
    var addresses = switch (addressAsync) {
      AsyncData(:final value) => value,
      _ => const <AddressEntity>[],
    };

    if (addresses.isEmpty) {
      final changed = await context.push<bool>(RouteNames.addAddress);
      if (!context.mounted) {
        return;
      }
      if (changed == true) {
        ref.read(addressProvider.notifier).refresh();
        try {
          await ref.read(addressProvider.future);
        } catch (_) {}
      }
      addresses = switch (ref.read(addressProvider)) {
        AsyncData(:final value) => value,
        _ => const <AddressEntity>[],
      };
    }

    if (addresses.isEmpty || !context.mounted) {
      return;
    }

    final selected = await showModalBottomSheet<AddressEntity>(
      context: context,
      showDragHandle: true,
      builder: (_) => _AddressPickerSheet(
        addresses: addresses,
        selected: ref.read(checkoutProvider).selectedAddress,
      ),
    );
    if (!context.mounted || selected == null) {
      return;
    }

    // Re-verify the picked address is actually deliverable before
    // accepting it — the add-address screen only checks this once, at
    // creation time. Nothing previously stopped a customer from switching
    // to a different saved address outside every shop's service area at
    // this final step and having the order fail (or previously, go
    // through unchecked). Fails open on a network/validation error rather
    // than blocking checkout on a transient hiccup — the backend's own
    // order-placement check remains the authoritative backstop regardless.
    final validation =
        await ref.read(validatePincodeUseCaseProvider).call(selected.pincode);
    final available =
        validation.fold((_) => true, (result) => result.available);
    if (!available) {
      if (!context.mounted) {
        return;
      }
      AppToast.show(
        context,
        '📍 We don\'t deliver to this address yet. Please choose a different one.',
        type: ToastType.warning,
      );
      return;
    }

    ref.read(checkoutProvider.notifier).selectAddress(selected);
  }

  // Reuses the exact same sheet the cart screen opens — checkout previously
  // only displayed the chosen delivery slot read-only, with no way to
  // change it without navigating back to the cart.
  Future<void> _openScheduleSheet(BuildContext context) async {
    // No separate Express/Schedule entry points here (unlike the cart
    // screen) — land on whichever tab matches the slot already chosen.
    final alreadyScheduled =
        ref.read(checkoutProvider).selectedDeliverySlot?.isScheduled ?? false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleDeliverySheet(initialScheduled: alreadyScheduled),
    );
  }

  /// Opens wallet top-up from the wallet toggle's "Add Money" button —
  /// pre-filled with the shortfall so the customer doesn't have to work out
  /// how much more they need — and refreshes the balance on return. The
  /// customer may have topped up even if they didn't pop with `true`, so
  /// always refresh rather than trusting the pop result.
  Future<void> _goToTopup(BuildContext context,
      {double? suggestedAmount}) async {
    await context.push<bool>(RouteNames.topup, extra: suggestedAmount);
    if (!mounted) {
      return;
    }
    ref.invalidate(walletProvider);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Bill Accordion
// ═══════════════════════════════════════════════════════════════════════════

class _BillAccordion extends StatelessWidget {
  const _BillAccordion({
    required this.summary,
    required this.billSummary,
    required this.billSummaryLoading,
    required this.expanded,
    required this.onToggle,
  });

  final CheckoutSummaryEntity summary;
  final BillSummaryEntity? billSummary;
  final bool billSummaryLoading;
  final bool expanded;
  final VoidCallback onToggle;

  /// Fee codes already rendered via dedicated rows above — anything else in
  /// `billSummary.fees` (e.g. SURGE_FEE / rain fee, PACKAGING_FEE) is
  /// rendered generically so a new admin-configured fee type never silently
  /// disappears from checkout.
  static const Set<String> _dedicatedFeeCodes = <String>{
    'DELIVERY_FEE',
    'HANDLING_FEE',
    'PLATFORM_FEE',
    'SMALL_CART_FEE',
  };

  double get _payable => billSummary?.payable ?? summary.total;

  /// Itemized breakdown — uses the backend canonical bill when available,
  /// otherwise falls back to the local summary so the row always renders.
  Widget _buildBreakdown() {
    final bs = billSummary;
    final divider = Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: const Divider(height: 1, color: AppColors.divider),
    );

    if (bs == null) {
      // While the real bill is still loading, never show the hardcoded
      // fallback fee amounts (AppConstants.standardDeliveryFee / platformFee)
      // as if they were authoritative — admin-configured fees (or a fee
      // toggled off entirely) could differ, and a stale-looking flash of
      // wrong numbers is exactly the "fee changes don't show up" complaint.
      // Show a loading placeholder instead until the backend responds.
      if (billSummaryLoading) {
        return Column(
          children: <Widget>[
            _BillRow(label: 'Items total', value: summary.subtotal),
            Gap(8.h),
            const _FeeRowSkeleton(),
            Gap(8.h),
            const _FeeRowSkeleton(),
            divider,
            const _FeeRowSkeleton(),
          ],
        );
      }
      // The backend fetch failed (not merely loading) — fall back to a
      // locally-estimated total so checkout isn't blocked, but label it
      // clearly as an estimate rather than presenting it as the real charge.
      return Column(
        children: <Widget>[
          _BillRow(label: 'Items total', value: summary.subtotal),
          Gap(8.h),
          _BillRow(
              label: 'Delivery fee (estimated)', value: summary.deliveryFee),
          Gap(8.h),
          _BillRow(
              label: 'Platform fee (estimated)', value: summary.platformFee),
          if (summary.discount > 0) ...<Widget>[
            Gap(8.h),
            _BillRow(
              label: 'Coupon discount',
              value: summary.discount,
              prefix: '-',
              valueColor: AppColors.successGreen,
            ),
          ],
          divider,
          _BillRow(
            label: 'Total (estimated)',
            value: summary.total,
            valueStyle: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w800),
          ),
          Gap(6.h),
          Text(
            "Couldn't load the latest fees — showing an estimate.",
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11.sp,
            ),
          ),
        ],
      );
    }

    final delivery = bs.deliveryFee;
    final rows = <Widget>[
      _BillRow(label: 'Items total', value: bs.itemTotal.discounted),
      Gap(8.h),
      _BillRow(
        label: 'Delivery fee',
        value: delivery.amount,
        isFree: delivery.isFree,
      ),
    ];
    if (!delivery.isFree && bs.distance.known && bs.distance.label.isNotEmpty) {
      rows
        ..add(Gap(4.h))
        ..add(
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${bs.distance.label} from store',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11.sp,
              ),
            ),
          ),
        );
    }
    if (delivery.isFree) {
      rows
        ..add(Gap(4.h))
        ..add(
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Free delivery unlocked',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.successGreen,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
    }
    if (bs.handlingFee.amount > 0) {
      rows
        ..add(Gap(8.h))
        ..add(_BillRow(label: 'Handling fee', value: bs.handlingFee.amount));
    }
    if (bs.platformFee.amount > 0) {
      rows
        ..add(Gap(8.h))
        ..add(_BillRow(label: 'Platform fee', value: bs.platformFee.amount));
    }
    if (bs.smallCartFee.amount > 0) {
      rows
        ..add(Gap(8.h))
        ..add(_BillRow(label: 'Small cart fee', value: bs.smallCartFee.amount));
    }
    // Other dynamic fees (rain/surge, packaging, etc.) — these only arrive
    // via the generic `fees` list; the codes above already have dedicated
    // rows so they're excluded here to avoid double-counting.
    for (final FeeLine fee in bs.fees.where(
      (FeeLine f) =>
          !_dedicatedFeeCodes.contains(f.code) && f.amount > 0 && !f.waived,
    )) {
      rows
        ..add(Gap(8.h))
        ..add(_BillRow(
            label: fee.label.isNotEmpty ? fee.label : 'Fee',
            value: fee.amount));
    }
    if (bs.couponDiscount > 0) {
      rows
        ..add(Gap(8.h))
        ..add(
          _BillRow(
            label: 'Coupon discount',
            value: bs.couponDiscount,
            prefix: '-',
            valueColor: AppColors.successGreen,
          ),
        );
    }
    if (bs.tipAmount > 0) {
      rows
        ..add(Gap(8.h))
        ..add(_BillRow(label: 'Delivery partner tip', value: bs.tipAmount));
    }
    rows
      ..add(divider)
      ..add(
        _BillRow(
          label: 'Total',
          value: bs.payable,
          valueStyle: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w800),
        ),
      );
    return Column(children: rows);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: const <BoxShadow>[AppShadows.cardShadow],
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              child: Row(
                children: <Widget>[
                  const _PaymentIconTile(icon: Icons.receipt_long_rounded),
                  Gap(12.w),
                  Text(
                    'To Pay',
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _payable.toInrCurrency,
                    style: AppTextStyles.h3.copyWith(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Gap(10.w),
                  Text(
                    expanded ? 'Hide' : 'View Bill',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Gap(2.w),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primaryGreen,
                      size: 18.sp,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              child: expanded
                  ? Column(
                      children: <Widget>[
                        Divider(
                          height: 1,
                          color: AppColors.divider,
                          indent: 16.w,
                          endIndent: 16.w,
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 14.h),
                          child: _buildBreakdown(),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.label,
    required this.value,
    this.prefix = '',
    this.valueColor,
    this.valueStyle,
    this.isFree = false,
  });

  final String label;
  final double value;
  final String prefix;
  final Color? valueColor;
  final TextStyle? valueStyle;
  final bool isFree;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
        ),
        Text(
          isFree ? 'FREE' : '$prefix${value.toInrCurrency}',
          style: valueStyle ??
              AppTextStyles.labelLarge.copyWith(
                color: isFree
                    ? AppColors.successGreen
                    : (valueColor ?? AppColors.textPrimary),
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

/// Lightweight placeholder row shown while the real fee breakdown is
/// loading, instead of the hardcoded local-estimate amounts.
class _FeeRowSkeleton extends StatelessWidget {
  const _FeeRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 90.w,
          height: 12.h,
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
        const Spacer(),
        Container(
          width: 48.w,
          height: 12.h,
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Order Items Review Card — shows each selected option clearly at checkout
// ═══════════════════════════════════════════════════════════════════════════

class _OrderItemsReviewCard extends StatelessWidget {
  const _OrderItemsReviewCard({required this.items});

  final List<CartItemEntity> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Order Summary',
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15.sp,
                ),
              ),
              const Spacer(),
              Text(
                '${items.length} item${items.length == 1 ? '' : 's'}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Gap(10.h),
          ...List<Widget>.generate(items.length, (index) {
            final item = items[index];
            return Padding(
              padding:
                  EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 10.h),
              child: _OrderItemReviewRow(item: item),
            );
          }),
        ],
      ),
    );
  }
}

class _OrderItemReviewRow extends StatelessWidget {
  const _OrderItemReviewRow({required this.item});

  final CartItemEntity item;

  @override
  Widget build(BuildContext context) {
    final optimized = ApiConstants.optimizedMedia(
      item.thumbnailUrl,
      profile: CustomerImageProfile.cartThumb,
    );
    // The option label (e.g. "500g", "4 x 95g") is the key disambiguator
    // between sibling options — surface it prominently next to the name.
    final optionLabel = item.optionLabel?.trim();
    final hasOption = optionLabel != null && optionLabel.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(8.r),
          child: SizedBox(
            width: 40.w,
            height: 40.w,
            child: (item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty)
                ? AppImage(
                    imageUrl: optimized.url ?? item.thumbnailUrl!,
                    memCacheWidth: optimized.memCacheWidth,
                    memCacheHeight: optimized.memCacheHeight,
                    fit: BoxFit.cover,
                    placeholder: const ColoredBox(color: Color(0xFFF4F4F4)),
                    errorWidget: const ColoredBox(
                      color: Color(0xFFF4F4F4),
                      child: Icon(
                        Icons.image_outlined,
                        size: 16,
                        color: Color(0xFFB5B5B5),
                      ),
                    ),
                  )
                : const ColoredBox(
                    color: Color(0xFFF4F4F4),
                    child: Icon(
                      Icons.image_outlined,
                      size: 16,
                      color: Color(0xFFB5B5B5),
                    ),
                  ),
          ),
        ),
        Gap(10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              Gap(2.h),
              Row(
                children: <Widget>[
                  if (hasOption)
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        optionLabel,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else if ((item.netQuantity ?? item.unit) != null &&
                      (item.netQuantity ?? item.unit)!.isNotEmpty)
                    Text(
                      item.netQuantity ?? item.unit!,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 11.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  Gap(6.w),
                  Text(
                    'Qty ${item.quantity}',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 11.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Gap(8.w),
        Text(
          '₹${item.total.toStringAsFixed(0)}',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Delivery Info Card
// ═══════════════════════════════════════════════════════════════════════════

class _DeliveryInfoCard extends StatelessWidget {
  const _DeliveryInfoCard({
    required this.address,
    required this.itemCount,
    required this.onChangeAddress,
    this.selectedSlot,
    this.onChangeSlot,
    this.onViewHoursTap,
  });

  final AddressEntity address;
  final int itemCount;
  final VoidCallback onChangeAddress;
  final SelectedDeliverySlot? selectedSlot;

  /// Opens the same schedule-delivery sheet the cart screen uses — checkout
  /// previously only showed the chosen slot read-only, with no way to
  /// change it without navigating back to the cart.
  final VoidCallback? onChangeSlot;

  /// Opens the "view store hours" sheet. Only rendered when provided.
  final VoidCallback? onViewHoursTap;

  @override
  Widget build(BuildContext context) {
    final slot = selectedSlot ?? const SelectedDeliverySlot.asap();
    final isScheduled = slot.isScheduled;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40.w,
                height: 40.w,
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreenLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: AppColors.primaryGreen,
                  size: 20.sp,
                ),
              ),
              Gap(12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          address.label,
                          style: AppTextStyles.labelLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.sp,
                          ),
                        ),
                        Gap(8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.orderVioletSurface,
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusFull),
                          ),
                          child: Text(
                            '$itemCount item${itemCount == 1 ? '' : 's'}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.orderViolet,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Gap(4.h),
                    Text(
                      _format(address),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              Gap(8.w),
              GestureDetector(
                onTap: onChangeAddress,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Change',
                      style: AppTextStyles.buttonSmall
                          .copyWith(color: AppColors.primaryGreen),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primaryGreen,
                      size: 16.sp,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // ── Scheduled delivery badge (tap to change) ──────────────
          if (isScheduled) ...[
            Gap(10.h),
            GestureDetector(
              onTap: onChangeSlot,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: const Color(0xFFDDD6FE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 14.sp,
                      color: AppColors.brandRed,
                    ),
                    Gap(6.w),
                    Expanded(
                      child: Text(
                        slot.slotLabel,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandRed,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    if (onChangeSlot != null) ...[
                      Gap(6.w),
                      Icon(
                        Icons.edit_calendar_outlined,
                        size: 14.sp,
                        color: AppColors.brandRed,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else if (onChangeSlot != null) ...[
            // ── ASAP: link to schedule instead ─────────────────────
            Gap(10.h),
            GestureDetector(
              onTap: onChangeSlot,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 14.sp,
                    color: AppColors.primaryGreen,
                  ),
                  Gap(6.w),
                  Text(
                    'Schedule for later instead',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (onViewHoursTap != null) ...[
            Gap(8.h),
            GestureDetector(
              onTap: onViewHoursTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 13.sp,
                    color: AppColors.textSecondary,
                  ),
                  Gap(5.w),
                  Text(
                    'Store hours',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _format(AddressEntity a) {
    return <String>[
      a.addressLine1,
      if (a.addressLine2 != null && a.addressLine2!.trim().isNotEmpty)
        a.addressLine2!.trim(),
      '${a.city}, ${a.state} ${a.pincode}',
    ].join(', ');
  }
}

class _AddAddressCard extends StatelessWidget {
  const _AddAddressCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border:
              Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.5)),
          boxShadow: const <BoxShadow>[AppShadows.cardShadow],
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.add_location_alt_outlined,
              color: AppColors.primaryGreen,
              size: 24.sp,
            ),
            Gap(12.w),
            Expanded(
              child: Text(
                'Choose delivery address',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primaryGreen,
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Payment selection primitives (premium minimalist)
// ═══════════════════════════════════════════════════════════════════════════

/// A leading rounded-square icon tile used across payment + summary cards.
class _PaymentIconTile extends StatelessWidget {
  const _PaymentIconTile({
    required this.icon,
    this.background = AppColors.orderVioletSurface,
    this.foreground = AppColors.orderViolet,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40.w,
      height: 40.w,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Icon(icon, color: foreground, size: 20.sp),
    );
  }
}

/// Animated radio indicator. Filled green ring when selected.
class _SelectionRadio extends StatelessWidget {
  const _SelectionRadio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 22.w,
      height: 22.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primaryGreen : AppColors.borderLight,
          width: selected ? 6.5 : 2,
        ),
      ),
    );
  }
}

/// Shared outer shell for a selectable payment card. Wraps content with a
/// white surface, an animated selection border, and press feedback.
class _PaymentCardShell extends StatelessWidget {
  const _PaymentCardShell({
    required this.selected,
    required this.onSelect,
    required this.child,
    this.disabled = false,
  });

  final bool selected;
  final VoidCallback onSelect;
  final Widget child;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(
            color: selected ? AppColors.primaryGreen : AppColors.borderLight,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: <BoxShadow>[
            if (selected)
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 6),
              )
            else
              AppShadows.cardShadow,
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: disabled ? null : onSelect,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Full-width primary action button shared by both payment cards.
class _PaymentActionButton extends StatelessWidget {
  const _PaymentActionButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50.h,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          disabledBackgroundColor:
              AppColors.primaryGreen.withValues(alpha: 0.45),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 18.w,
                height: 18.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(icon, color: Colors.white, size: 17.sp),
                  Gap(8.w),
                  Text(
                    label,
                    style: AppTextStyles.buttonMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Razorpay Payment Card  (minimal, selectable)
// ═══════════════════════════════════════════════════════════════════════════

class _RazorpayPaymentCard extends StatelessWidget {
  const _RazorpayPaymentCard({
    required this.total,
    required this.selected,
    required this.onSelect,
    required this.onPay,
    required this.isPlacingOrder,
  });

  final double total;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onPay;
  final bool isPlacingOrder;

  @override
  Widget build(BuildContext context) {
    return _PaymentCardShell(
      selected: selected,
      onSelect: onSelect,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const _PaymentIconTile(
                  icon: Icons.bolt_rounded,
                  background: AppColors.primaryGreenLight,
                  foreground: AppColors.primaryGreen,
                ),
                Gap(12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            'Pay Online',
                            style: AppTextStyles.labelLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15.sp,
                            ),
                          ),
                          Gap(8.w),
                          const _RazorpayBadge(),
                        ],
                      ),
                      Gap(2.h),
                      Text(
                        'UPI • Cards • Netbanking & more',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Gap(8.w),
                _SelectionRadio(selected: selected),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: selected
                  ? Padding(
                      padding: EdgeInsets.only(top: 14.h),
                      child: _PaymentActionButton(
                        label: 'Pay ${total.toInrCurrency} Online',
                        icon: Icons.lock_rounded,
                        isLoading: isPlacingOrder,
                        onPressed: isPlacingOrder ? null : onPay,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _RazorpayBadge extends StatelessWidget {
  const _RazorpayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: const Color(0xFF072654),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
      ),
      child: Text(
        'Razorpay',
        style: AppTextStyles.bodySmall.copyWith(
          color: Colors.white,
          fontSize: 9.sp,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Cash on Delivery Card  (minimal, selectable — greys out + shows a reason
// when the live bill total is outside the admin-configured COD range)
// ═══════════════════════════════════════════════════════════════════════════

class _CodPaymentCard extends StatelessWidget {
  const _CodPaymentCard({
    required this.total,
    required this.available,
    required this.reason,
    required this.selected,
    required this.onSelect,
    required this.onPlaceOrder,
    required this.isPlacingOrder,
  });

  final double total;
  final bool available;
  final String? reason;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onPlaceOrder;
  final bool isPlacingOrder;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected && available;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PaymentCardShell(
          selected: isSelected,
          disabled: !available,
          onSelect: onSelect,
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const _PaymentIconTile(
                      icon: Icons.payments_outlined,
                      background: Color(0xFFFFF3E0),
                      foreground: Color(0xFFB45309),
                    ),
                    Gap(12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Cash on Delivery',
                            style: AppTextStyles.labelLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15.sp,
                            ),
                          ),
                          Gap(2.h),
                          Text(
                            'Pay when your order arrives',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Gap(8.w),
                    _SelectionRadio(selected: isSelected),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: isSelected
                      ? Padding(
                          padding: EdgeInsets.only(top: 14.h),
                          child: _PaymentActionButton(
                            label: 'Place Order (Pay on Delivery)',
                            icon: Icons.lock_rounded,
                            isLoading: isPlacingOrder,
                            onPressed: isPlacingOrder ? null : onPlaceOrder,
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
        if (!available && reason != null) ...<Widget>[
          Gap(8.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.errorRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border:
                  Border.all(color: AppColors.errorRed.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.errorRed,
                  size: 16.sp,
                ),
                Gap(8.w),
                Expanded(
                  child: Text(
                    reason!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.errorRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Secure payment badge
// ═══════════════════════════════════════════════════════════════════════════

class _SecurePaymentBadge extends StatelessWidget {
  const _SecurePaymentBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(
          Icons.verified_user_rounded,
          size: 14.sp,
          color: AppColors.orderViolet,
        ),
        Gap(6.w),
        Text.rich(
          TextSpan(
            text: 'Secure payments powered by ',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            children: <InlineSpan>[
              TextSpan(
                text: 'Razorpay',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Footer
// ═══════════════════════════════════════════════════════════════════════════

class _CheckoutFooter extends StatelessWidget {
  const _CheckoutFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const _FooterRow(
          icon: Icons.info_outline_rounded,
          text:
              'Orders can be cancelled until the store starts packing them. Refunds for prepaid orders are processed automatically.',
        ),
        Gap(8.h),
        const _FooterRow(
          icon: Icons.lock_outlined,
          text: 'Your payment is secured with 256-bit SSL encryption.',
        ),
      ],
    );
  }
}

class _FooterRow extends StatelessWidget {
  const _FooterRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 14.sp, color: AppColors.textTertiary),
        Gap(8.w),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
              fontSize: 11.sp,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Bottom Bar
// ═══════════════════════════════════════════════════════════════════════════

class _CheckoutBottomBar extends StatelessWidget {
  const _CheckoutBottomBar({
    required this.summary,
    required this.isLoading,
    required this.onPlaceOrder,
    required this.showWalletToggle,
    required this.walletBalance,
    required this.walletLoading,
    required this.useWallet,
    required this.walletApplied,
    required this.orderTotal,
    required this.onToggleWallet,
    this.onAddMoney,
    this.onPayFullWallet,
  });

  final CheckoutSummaryEntity summary;
  final bool isLoading;
  final VoidCallback onPlaceOrder;
  final bool showWalletToggle;
  final double walletBalance;
  final bool walletLoading;
  final bool useWallet;
  final double walletApplied;

  /// The order's real payable total, before any wallet offset — used only
  /// to decide whether the wallet row's expanded action is "Pay via Wallet"
  /// or "Add Money". `summary.total` is already the post-wallet remainder.
  final double orderTotal;
  final ValueChanged<bool> onToggleWallet;
  final VoidCallback? onAddMoney;
  final VoidCallback? onPayFullWallet;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: <BoxShadow>[AppShadows.floatingShadow],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (showWalletToggle) ...<Widget>[
              _WalletToggleRow(
                walletBalance: walletBalance,
                walletApplied: walletApplied,
                orderTotal: orderTotal,
                value: useWallet,
                enabled: !walletLoading && !isLoading,
                onChanged: onToggleWallet,
                onAddMoney: onAddMoney,
                onPayFullWallet: onPayFullWallet,
              ),
              Gap(10.h),
            ],
            Row(
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Total payable',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      Text(
                        summary.total.toInrCurrency,
                        style: AppTextStyles.h2.copyWith(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Gap(12.w),
                Expanded(
                  flex: 3,
                  child: FilledButton(
                    onPressed: isLoading ? null : onPlaceOrder,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      disabledBackgroundColor: AppColors.borderLight,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Place Order',
                            style: AppTextStyles.buttonMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Toggle row shown above the total/Place Order row when the customer has
/// wallet balance available — applies (or reverts) the wallet offset
/// against whichever payment method is currently selected, rather than
/// requiring wallet as a separate exclusive payment method.
/// Wallet card — a self-contained "Bakaloo Wallet" payment card, offsetting
/// [_CheckoutBottomBar]'s "Total payable" figure regardless of the chosen
/// payment method. Shown only when the admin allows wallet at all (even at
/// zero balance).
///
/// The switch reveals one panel below it: "You saved ₹X with Bakaloo
/// Wallet" alongside a contextual action — "Pay via Wallet" (balance fully
/// covers the order — one tap, nothing else to collect) when there's
/// enough, or "Add Money" (pre-filled with exactly the shortfall) when
/// there isn't. A customer who doesn't want either can simply use Place
/// Order as normal — the switch still applies whatever balance exists as a
/// partial discount in the background.
class _WalletToggleRow extends StatelessWidget {
  const _WalletToggleRow({
    required this.walletBalance,
    required this.walletApplied,
    required this.orderTotal,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.onAddMoney,
    this.onPayFullWallet,
  });

  final double walletBalance;
  final double walletApplied;
  final double orderTotal;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onAddMoney;
  final VoidCallback? onPayFullWallet;

  static const _brandRed = AppColors.brandRed;
  static const _redBg = AppColors.brandRedSurface;
  static const _borderColor = AppColors.brandRedBorder;
  static const _titleColor = Color(0xFF171717);
  static const _mutedGray = Color(0xFF737684);

  bool get _hasBalance => walletBalance > 0;
  bool get _sufficient => walletBalance >= orderTotal && orderTotal > 0;

  @override
  Widget build(BuildContext context) {
    final active = value && _hasBalance && !_sufficient;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Colors.white, Color(0xFFFAF8FF)],
        ),
        borderRadius: BorderRadius.circular(17.r),
        border: Border.all(color: _borderColor),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: _redBg,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: _brandRed,
              size: 20.sp,
            ),
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Bakaloo Wallet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: _titleColor,
                    fontFamily: 'Inter',
                  ),
                ),
                Gap(3.h),
                Text.rich(
                  _sufficient
                      ? TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: '${walletBalance.toInrCurrency} ',
                              style: const TextStyle(
                                color: _brandRed,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(text: 'available  |  '),
                            TextSpan(
                              text: '${orderTotal.toInrCurrency} ',
                              style: const TextStyle(
                                color: _brandRed,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(text: 'order total'),
                          ],
                        )
                      : active && walletApplied > 0
                          ? TextSpan(
                              children: <InlineSpan>[
                                TextSpan(
                                  text: '${walletApplied.toInrCurrency} ',
                                  style: const TextStyle(
                                    color: _brandRed,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const TextSpan(text: 'applied  |  '),
                                TextSpan(
                                  text: '${walletBalance.toInrCurrency} ',
                                  style: const TextStyle(
                                    color: _brandRed,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const TextSpan(text: 'available'),
                              ],
                            )
                          : TextSpan(
                              text: _hasBalance
                                  ? '${walletBalance.toInrCurrency} available'
                                  : 'No balance yet',
                            ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: _mutedGray,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          Gap(8.w),
          if (_sufficient)
            _PayWithWalletButton(onPressed: enabled ? onPayFullWallet : null)
          else ...<Widget>[
            _AddMoneyButton(onPressed: enabled ? onAddMoney : null),
            Gap(8.w),
            _CheckmarkToggle(
              value: value,
              enabled: enabled,
              onChanged: onChanged,
            ),
          ],
        ],
      ),
    );
  }
}

/// A compact checkbox-style toggle — a filled purple checkmark (on) or an
/// outlined circle (off) — used instead of a [Switch] specifically because
/// Switch's minimum track width (~34dp, ~90px on this density) was, next to
/// the "Add Money" button, squeezing the wallet card's title/subtitle text
/// column down to where "Bakaloo Wallet" wrapped onto two lines and the
/// whole card ballooned past its intended compact height. This toggle is
/// roughly a third of that width.
class _CheckmarkToggle extends StatelessWidget {
  const _CheckmarkToggle({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  static const _brandRed = AppColors.brandRed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: enabled ? () => onChanged(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 24.w,
        height: 24.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: value ? _brandRed : Colors.transparent,
          border: Border.all(
            color: value ? _brandRed : const Color(0xFFC7C7CC),
            width: 1.6,
          ),
        ),
        child: value
            ? Icon(Icons.check_rounded, color: Colors.white, size: 15.sp)
            : null,
      ),
    );
  }
}

/// The single, primary CTA shown instead of the switch/Add Money pair once
/// the wallet balance alone covers the order — a filled purple gradient
/// pill, the strongest visual weight in the row since it's a one-tap
/// commit, not a navigation.
class _PayWithWalletButton extends StatelessWidget {
  const _PayWithWalletButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(13.r),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(13.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: onPressed != null
                  ? const <Color>[AppColors.brandRed, AppColors.brandRedDark]
                  : <Color>[
                      AppColors.brandRed.withValues(alpha: 0.4),
                      AppColors.brandRedDark.withValues(alpha: 0.4),
                    ],
            ),
            borderRadius: BorderRadius.circular(13.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 16.sp,
              ),
              Gap(6.w),
              Text(
                'Pay with Wallet',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The compact outlined "Add Money" button shown alongside the switch when
/// the balance doesn't yet cover the order — navigates to top-up,
/// pre-filled with the shortfall.
class _AddMoneyButton extends StatelessWidget {
  const _AddMoneyButton({required this.onPressed});

  final VoidCallback? onPressed;

  static const _brandRed = AppColors.brandRed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _brandRed,
        backgroundColor: Colors.white,
        side: const BorderSide(color: _brandRed, width: 1.5),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13.r),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.add_rounded, size: 14.sp),
          Gap(3.w),
          Text(
            'Add Money',
            style: TextStyle(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Empty State
// ═══════════════════════════════════════════════════════════════════════════

/// Shown in place of an instant failure whenever the checkout SDK reports
/// an ambiguous result — the bank/UPI side can already have succeeded, so
/// this deliberately says neither "success" nor "failed" while the backend
/// is asked to confirm. Non-modal on purpose: the customer can keep
/// browsing (the poll keeps running regardless), but the submit button is
/// disabled for the duration to prevent a duplicate payment attempt.
class _PendingConfirmationBanner extends StatelessWidget {
  const _PendingConfirmationBanner({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      color: AppColors.orderStatusAmberBg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18.w,
            height: 18.w,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.orderStatusAmber,
            ),
          ),
          Gap(10.w),
          Expanded(
            child: Text(
              message ?? 'Verifying your payment…',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.orderStatusAmber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.shopping_cart_outlined,
              size: 56.sp,
              color: AppColors.textDisabled,
            ),
            Gap(12.h),
            Text(
              message,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Address Picker Sheet
// ═══════════════════════════════════════════════════════════════════════════

class _AddressPickerSheet extends StatelessWidget {
  const _AddressPickerSheet({
    required this.addresses,
    required this.selected,
  });

  final List<AddressEntity> addresses;
  final AddressEntity? selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
        itemCount: addresses.length,
        separatorBuilder: (_, __) => Gap(10.h),
        itemBuilder: (context, index) {
          final address = addresses[index];
          final isSelected = selected?.id == address.id;
          return InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            onTap: () => Navigator.of(context).pop(address),
            child: Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color:
                    isSelected ? AppColors.primaryGreenLight : AppColors.bgCard,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryGreen
                      : AppColors.borderLight,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isSelected
                        ? AppColors.primaryGreen
                        : AppColors.borderLight,
                    size: 20.sp,
                  ),
                  Gap(10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${address.label} • ${address.name}',
                          style: AppTextStyles.labelLarge
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        Gap(3.h),
                        Text(
                          <String>[
                            address.addressLine1,
                            '${address.city}, ${address.state}',
                          ].join(', '),
                          style: AppTextStyles.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
