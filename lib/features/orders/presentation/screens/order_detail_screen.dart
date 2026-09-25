import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/active_order_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_detail_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_list_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_details/order_address_card.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_details/order_detail_palette.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_details/order_header_card.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_details/order_items_card.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_details/order_qr_card.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_details/order_timeline.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_details/payment_summary_card.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_details/sticky_order_actions.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/domain/entities/refund_request_status_entity.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/presentation/providers/refund_request_provider.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/presentation/screens/refund_request_screen.dart';
import 'package:bakaloo_flutter_app/features/reviews/presentation/screens/order_review_screen.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/widgets/cancel_order_sheet.dart';
import 'package:bakaloo_flutter_app/shared/widgets/contact_support_sheet.dart';

/// FreshCuts Order Details screen. Real backend-driven data throughout —
/// order id/number/status/timeline/items/address/payment come straight off
/// [OrderEntity] (via [orderDetailProvider]); nothing here is mocked. See
/// the widgets under `presentation/widgets/order_details/` for the
/// per-section breakdown (OrderHeaderCard, OrderQrCard, OrderTimeline,
/// OrderAddressCard, OrderItemsCard/OrderItemTile, PaymentSummaryCard,
/// StickyOrderActions).
class OrderDetailsScreen extends ConsumerStatefulWidget {
  const OrderDetailsScreen({
    required this.id,
    super.key,
  });

  final String id;

  @override
  ConsumerState<OrderDetailsScreen> createState() =>
      _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  bool _isCancelling = false;
  bool _isReordering = false;
  bool _isDownloadingInvoice = false;

  Future<void> _cancelOrder(OrderEntity order) async {
    if (_isCancelling) return;

    final reason = await CancelOrderSheet.show(
      context,
      orderNumber: order.orderNumber,
    );
    if (reason == null || !mounted) return;

    setState(() => _isCancelling = true);

    final result = await ref
        .read(orderListControllerProvider)
        .cancelOrder(order.id, reason: reason);
    if (!mounted) return;

    setState(() => _isCancelling = false);

    result.fold(
      (failure) => AppToast.show(context, failure.message),
      (_) {
        ref
          ..invalidate(activeOrderProvider)
          ..invalidate(orderDetailProvider(order.id));
        AppToast.show(
          context,
          '✅ Order cancelled successfully',
          type: ToastType.success,
        );
      },
    );
  }

  Future<void> _reorder(OrderEntity order) async {
    if (_isReordering) return;

    setState(() => _isReordering = true);
    final result =
        await ref.read(orderListControllerProvider).reorder(order.id);

    if (!mounted) return;
    setState(() => _isReordering = false);

    result.fold(
      (failure) => AppToast.show(context, failure.message),
      (data) {
        ref.invalidate(cartProvider);
        final warnings =
            data.warnings.isEmpty ? '' : '\n${data.warnings.join('\n')}';
        AppToast.show(
          context,
          data.itemCount > 0
              ? '${data.itemCount} item(s) added to cart$warnings'
              : 'Nothing could be added to your cart$warnings',
          type: data.itemCount > 0 ? ToastType.success : ToastType.error,
        );
        if (data.itemCount > 0) {
          context.push(RouteNames.cart);
        }
      },
    );
  }

  Future<void> _downloadInvoice(OrderEntity order) async {
    if (_isDownloadingInvoice) return;

    setState(() => _isDownloadingInvoice = true);
    final result =
        await ref.read(orderListControllerProvider).downloadInvoice(order.id);

    if (!mounted) return;
    setState(() => _isDownloadingInvoice = false);

    await result.fold(
      (failure) async => AppToast.show(context, failure.message),
      (file) async {
        final openResult = await OpenFile.open(file.path);
        if (!mounted) return;
        final message = openResult.type == ResultType.done
            ? 'Invoice downloaded: ${file.fileName}'
            : openResult.message;
        AppToast.show(
          context,
          message,
          type: message.startsWith('Invoice')
              ? ToastType.success
              : ToastType.error,
        );
      },
    );
  }

  Future<void> _cancelRefundRequest(OrderEntity order, String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel refund request?'),
        content: const Text(
          "This withdraws your request — no money moves. You'll be able to raise a new one for this order afterwards.",
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Request'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result =
        await ref.read(refundRequestProvider.notifier).cancelRequest(requestId);
    if (!mounted) return;

    if (!result.isSuccess) {
      AppToast.show(context, result.failure!.message);
      return;
    }
    ref.invalidate(refundRequestByOrderProvider(order.id));
    AppToast.show(context, 'Refund request cancelled', type: ToastType.success);
  }

  Future<void> _showNeedHelpSheet() {
    return showContactSupportSheet(
      context,
      title: 'Need help with this order?',
    );
  }

  void _onStickyPrimaryAction(OrderEntity order) {
    switch (order.status) {
      case OrderStatus.PENDING:
      case OrderStatus.CONFIRMED:
      case OrderStatus.PREPARING:
        _cancelOrder(order);
      case OrderStatus.PACKED:
      case OrderStatus.OUT_FOR_DELIVERY:
        context.push('/orders/${order.id}/track');
      case OrderStatus.DELIVERED:
      case OrderStatus.CANCELLED:
      case OrderStatus.REFUNDED:
        _reorder(order);
    }
  }

  bool _stickyIsBusy(OrderEntity order) {
    switch (order.status) {
      case OrderStatus.PENDING:
      case OrderStatus.CONFIRMED:
      case OrderStatus.PREPARING:
        return _isCancelling;
      case OrderStatus.PACKED:
      case OrderStatus.OUT_FOR_DELIVERY:
        return false;
      case OrderStatus.DELIVERED:
      case OrderStatus.CANCELLED:
      case OrderStatus.REFUNDED:
        return _isReordering;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.id));
    final cartCount = ref.watch(cartCountProvider);

    return Scaffold(
      backgroundColor: OrderDetailPalette.screenBg,
      appBar: _OrderDetailsAppBar(
        cartCount: cartCount,
        onHelp: _showNeedHelpSheet,
      ),
      body: orderAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: OrderDetailPalette.primaryRed,
          ),
        ),
        error: (error, _) => _DetailErrorState(
          message: error.toString().replaceFirst('Bad state: ', ''),
          onRetry: () => ref.invalidate(orderDetailProvider(widget.id)),
        ),
        data: (order) {
          final refundRequestAsync =
              ref.watch(refundRequestByOrderProvider(order.id));
          final refundRequest = refundRequestAsync.asData?.value;
          final canDownloadInvoice =
              order.paymentStatus.toUpperCase() == 'PAID';
          final canRequestExtras = order.status == OrderStatus.DELIVERED;

          return Stack(
            children: <Widget>[
              ListView(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 110.h),
                children: <Widget>[
                  OrderHeaderCard(
                    order: order,
                    onReorder: () => _reorder(order),
                    isReordering: _isReordering,
                  ),
                  Gap(12.h),
                  OrderQrCard(order: order),
                  Gap(12.h),
                  _CardShell(
                    title: 'Order Timeline',
                    child: OrderTimeline(order: order),
                  ),
                  Gap(12.h),
                  OrderStatusBanner(
                    order: order,
                    onReorder: () => _reorder(order),
                    isReordering: _isReordering,
                  ),
                  Gap(12.h),
                  OrderItemsCard(
                    items: order.items,
                    onDownloadInvoice: () => _downloadInvoice(order),
                    isDownloadingInvoice: _isDownloadingInvoice,
                    canDownloadInvoice: canDownloadInvoice,
                  ),
                  Gap(12.h),
                  PaymentSummaryCard(order: order),
                  Gap(12.h),
                  OrderAddressCard(order: order),
                  if (refundRequest != null) ...<Widget>[
                    Gap(12.h),
                    _CardShell(
                      title: 'Refund Request',
                      child: _RefundRequestStatusCard(
                        request: refundRequest,
                        onCancel: () =>
                            _cancelRefundRequest(order, refundRequest.id),
                      ),
                    ),
                  ],
                  if (canRequestExtras &&
                      refundRequest?.blocksNewRequest != true) ...<Widget>[
                    Gap(12.h),
                    _MoreActionsRow(
                      onWriteReview: () => Navigator.of(context).push(
                        MaterialPageRoute<bool>(
                          builder: (_) => OrderReviewScreen(order: order),
                        ),
                      ),
                      onRequestRefund: () => Navigator.of(context).push(
                        MaterialPageRoute<bool>(
                          builder: (_) => RefundRequestScreen(order: order),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: orderAsync.maybeWhen(
        data: (order) => StickyOrderActions(
          order: order,
          onNeedHelp: _showNeedHelpSheet,
          onPrimaryAction: () => _onStickyPrimaryAction(order),
          isBusy: _stickyIsBusy(order),
        ),
        orElse: () => null,
      ),
    );
  }
}

class _OrderDetailsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _OrderDetailsAppBar({required this.cartCount, required this.onHelp});

  final int cartCount;
  final VoidCallback onHelp;

  @override
  Size get preferredSize => Size.fromHeight(56.h);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: OrderDetailPalette.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        onPressed: () =>
            context.canPop() ? context.pop() : context.go(RouteNames.orders),
        icon: Icon(
          Icons.arrow_back,
          size: 22.sp,
          color: OrderDetailPalette.textPrimary,
        ),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Image.asset(
            'assets/icon/brand_logo.png',
            height: 24.h,
            cacheHeight: 96,
            fit: BoxFit.contain,
          ),
          Gap(6.w),
          Text(
            'FreshCuts',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              color: OrderDetailPalette.textPrimary,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: <Widget>[
        _AppBarIconButton(
          icon: PhosphorIcons.headset,
          semanticLabel: 'Help',
          onTap: onHelp,
        ),
        _AppBarIconButton(
          icon: PhosphorIcons.handbagBold,
          semanticLabel: 'Cart',
          badgeCount: cartCount,
          onTap: () => context.push(RouteNames.cart),
        ),
        Gap(4.w),
      ],
    );
  }
}

class _AppBarIconButton extends StatelessWidget {
  const _AppBarIconButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.badgeCount = 0,
  });

  final PhosphorIconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 38.w,
          height: 38.w,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              PhosphorIcon(
                icon,
                size: 20.sp,
                color: OrderDetailPalette.textPrimary,
              ),
              if (badgeCount > 0)
                Positioned(
                  right: 2.w,
                  top: 2.h,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                    constraints: BoxConstraints(minWidth: 16.w),
                    decoration: BoxDecoration(
                      color: OrderDetailPalette.ctaRed,
                      borderRadius: BorderRadius.circular(100.r),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A plain, titled white card — used for sections that don't need their own
/// dedicated widget file (currently just the timeline wrapper).
class _CardShell extends StatelessWidget {
  const _CardShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: OrderDetailPalette.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: OrderDetailPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.5.sp,
              fontWeight: FontWeight.w700,
              color: OrderDetailPalette.textPrimary,
            ),
          ),
          Gap(16.h),
          child,
        ],
      ),
    );
  }
}

class _MoreActionsRow extends StatelessWidget {
  const _MoreActionsRow({
    required this.onWriteReview,
    required this.onRequestRefund,
  });

  final VoidCallback onWriteReview;
  final VoidCallback onRequestRefund;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: SizedBox(
            height: 44.h,
            child: OutlinedButton(
              onPressed: onWriteReview,
              style: OutlinedButton.styleFrom(
                foregroundColor: OrderDetailPalette.textPrimary,
                side: const BorderSide(color: OrderDetailPalette.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: const Text('Write Review'),
            ),
          ),
        ),
        Gap(10.w),
        Expanded(
          child: SizedBox(
            height: 44.h,
            child: OutlinedButton(
              onPressed: onRequestRefund,
              style: OutlinedButton.styleFrom(
                foregroundColor: OrderDetailPalette.primaryRed,
                side: const BorderSide(color: OrderDetailPalette.primaryRed),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: const Text('Request Refund'),
            ),
          ),
        ),
      ],
    );
  }
}

class _RefundRequestStatusCard extends StatelessWidget {
  const _RefundRequestStatusCard({
    required this.request,
    required this.onCancel,
  });

  final RefundRequestStatusEntity request;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final (Color accent, IconData icon, String title, String subtitle) =
        switch (request.status) {
      'PENDING' => (
          OrderDetailPalette.primaryRed,
          PhosphorIcons.clockCountdown,
          'Refund request pending',
          "We've received your request — our team will review it and connect with you within 24 hours.",
        ),
      'APPROVED' => (
          OrderDetailPalette.successGreen,
          PhosphorIcons.checkCircleFill,
          'Refund approved',
          request.refundAmount != null
              ? '₹${request.refundAmount!.toStringAsFixed(0)} credited to your ${request.refundTo == 'original' ? 'original payment method' : 'wallet'}.'
              : 'Your refund has been processed.',
        ),
      'REJECTED' => (
          const Color(0xFFD32F2F),
          PhosphorIcons.xCircleFill,
          'Refund request rejected',
          (request.adminNote ?? '').trim().isNotEmpty
              ? request.adminNote!.trim()
              : 'Our team reviewed this request and it was not approved.',
        ),
      _ => (
          OrderDetailPalette.textSecondary,
          PhosphorIcons.prohibit,
          'Refund request cancelled',
          "You cancelled this request. You're free to raise a new one if the issue is still unresolved.",
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 20.sp, color: accent),
            Gap(10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  Gap(4.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5.sp,
                      color: OrderDetailPalette.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (request.description.trim().isNotEmpty) ...<Widget>[
          Gap(8.h),
          Text(
            '"${request.description.trim()}"',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5.sp,
              color: OrderDetailPalette.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (request.isPending) ...<Widget>[
          Gap(10.h),
          SizedBox(
            width: double.infinity,
            height: 42.h,
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: OrderDetailPalette.textPrimary,
                side: const BorderSide(color: OrderDetailPalette.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: const Text('Cancel Request'),
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailErrorState extends StatelessWidget {
  const _DetailErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: 40.sp,
              color: OrderDetailPalette.primaryRed,
            ),
            Gap(10.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5.sp,
                color: OrderDetailPalette.textSecondary,
              ),
            ),
            Gap(12.h),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: OrderDetailPalette.primaryRed,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
