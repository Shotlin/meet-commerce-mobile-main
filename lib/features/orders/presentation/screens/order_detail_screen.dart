import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/datetime_extensions.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/active_order_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_detail_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_list_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/services/invoice_opener.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/domain/entities/refund_request_status_entity.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/presentation/providers/refund_request_provider.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/presentation/screens/refund_request_screen.dart';
import 'package:bakaloo_flutter_app/features/reviews/presentation/screens/order_review_screen.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/widgets/cancel_order_sheet.dart';
import 'package:bakaloo_flutter_app/shared/widgets/safe_product_image.dart';

/// Title-cases a snake/enum-ish string, e.g. 'CASH_ON_DELIVERY' -> 'Cash On
/// Delivery'. `_PaymentInfo` below has its own identically-named instance
/// method for its own use; this top-level one is for `_PriceBreakdown`'s
/// "Balance due (Method)" label, which isn't part of that class.
String _prettyText(String value) {
  return value.trim().toLowerCase().split('_').map((part) {
    if (part.isEmpty) {
      return '';
    }
    return '${part[0].toUpperCase()}${part.substring(1)}';
  }).join(' ');
}

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({
    required this.id,
    super.key,
  });

  final String id;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _isCancelling = false;
  bool _isReordering = false;
  bool _isDownloadingInvoice = false;

  Future<void> _cancelOrder(OrderEntity order) async {
    if (_isCancelling) {
      return;
    }

    final reason = await CancelOrderSheet.show(
      context,
      orderNumber: order.orderNumber,
    );
    if (reason == null || !mounted) {
      return;
    }

    setState(() {
      _isCancelling = true;
    });

    final result = await ref
        .read(orderListControllerProvider)
        .cancelOrder(order.id, reason: reason);
    if (!mounted) {
      return;
    }

    setState(() {
      _isCancelling = false;
    });

    result.fold(
      (failure) {
        AppToast.show(context, failure.message);
      },
      (_) {
        ref
          ..invalidate(activeOrderProvider)
          ..invalidate(orderDetailProvider(order.id));
        AppToast.show(context, '✅ Order cancelled successfully',
            type: ToastType.success);
      },
    );
  }

  Future<void> _reorder(OrderEntity order) async {
    if (_isReordering) {
      return;
    }

    setState(() {
      _isReordering = true;
    });
    final result =
        await ref.read(orderListControllerProvider).reorder(order.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _isReordering = false;
    });

    result.fold(
      (failure) {
        AppToast.show(context, failure.message);
      },
      (data) {
        ref.invalidate(cartProvider);
        final warnings =
            data.warnings.isEmpty ? '' : '\n${data.warnings.join('\n')}';
        AppToast.show(context, 'Items added to cart$warnings',
            type: ToastType.success);
        // Navigate to the cart so the reorder produces a visible result.
        context.push(RouteNames.cart);
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
    if (confirmed != true || !mounted) {
      return;
    }

    final result =
        await ref.read(refundRequestProvider.notifier).cancelRequest(requestId);
    if (!mounted) {
      return;
    }

    if (!result.isSuccess) {
      AppToast.show(context, result.failure!.message);
      return;
    }
    ref.invalidate(refundRequestByOrderProvider(order.id));
    AppToast.show(context, 'Refund request cancelled', type: ToastType.success);
  }

  Future<void> _downloadInvoice(OrderEntity order) async {
    if (_isDownloadingInvoice) {
      return;
    }

    setState(() {
      _isDownloadingInvoice = true;
    });
    final result =
        await ref.read(orderListControllerProvider).downloadInvoice(order.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _isDownloadingInvoice = false;
    });

    await result.fold(
      (failure) async {
        AppToast.show(context, failure.message);
      },
      (file) async {
        final openResult = await openInvoice(file);
        if (!mounted) {
          return;
        }
        final message = openResult.message;
        AppToast.show(context, message,
            type: openResult.isSuccess
                ? ToastType.success
                : ToastType.error);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.id));

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text('Order details', style: AppTextStyles.h2),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () => context.push('/orders/${widget.id}/track'),
            icon: PhosphorIcon(
              PhosphorIcons.navigationArrow,
              size: 16.sp,
            ),
            label: Text(
              'Track',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
              padding: EdgeInsets.symmetric(horizontal: 12.w),
            ),
          ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
        error: (error, _) => _DetailErrorState(
          message: error.toString().replaceFirst('Bad state: ', ''),
          onRetry: () => ref.invalidate(orderDetailProvider(widget.id)),
        ),
        data: (order) {
          final refundRequestAsync =
              ref.watch(refundRequestByOrderProvider(order.id));
          final refundRequest = refundRequestAsync.asData?.value;

          return ListView(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
            children: <Widget>[
              _StatusHero(order: order),
              Gap(16.h),
              _SectionCard(
                title: 'Order timeline',
                child: _TimelineStepper(order: order),
              ),
              Gap(16.h),
              _SectionCard(
                title: 'Items',
                child: Column(
                  children: order.items
                      .map((item) => _OrderItemRow(item: item))
                      .toList(growable: false),
                ),
              ),
              Gap(16.h),
              _SectionCard(
                title: 'Price breakdown',
                child: _PriceBreakdown(order: order),
              ),
              Gap(16.h),
              _SectionCard(
                title: 'Delivery address',
                child: _AddressInfo(order: order),
              ),
              if (order.deliveryOtp != null &&
                  order.deliveryOtp!.trim().isNotEmpty) ...<Widget>[
                Gap(16.h),
                _SectionCard(
                  title: 'Delivery OTP',
                  child: _DeliveryOtpRow(otp: order.deliveryOtp!.trim()),
                ),
              ],
              Gap(16.h),
              _SectionCard(
                title: 'Payment',
                child: _PaymentInfo(order: order),
              ),
              if (refundRequest != null) ...<Widget>[
                Gap(16.h),
                _SectionCard(
                  title: 'Refund Request',
                  child: _RefundRequestStatusCard(
                    request: refundRequest,
                    onCancel: () =>
                        _cancelRefundRequest(order, refundRequest.id),
                  ),
                ),
              ],
              Gap(16.h),
              _OrderActions(
                order: order,
                isCancelling: _isCancelling,
                isReordering: _isReordering,
                isDownloadingInvoice: _isDownloadingInvoice,
                canRequestRefund: refundRequest?.blocksNewRequest != true,
                onCancel: () => _cancelOrder(order),
                onReorder: () => _reorder(order),
                onDownloadInvoice: () => _downloadInvoice(order),
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
          );
        },
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.order});

  final OrderEntity order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 96.w,
            height: 96.w,
            child: Lottie.asset(
              _animationForStatus(order.status),
              fit: BoxFit.contain,
              repeat: true,
              errorBuilder: (_, __, ___) => CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(
                  Icons.local_shipping_outlined,
                  color: Colors.white,
                  size: 28.sp,
                ),
              ),
            ),
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  order.isPaymentFailed ? 'Failed' : order.status.label,
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.textOnGreen,
                    fontSize: 20.sp,
                  ),
                ),
                Gap(6.h),
                Text(
                  order.isPaymentFailed
                      ? "Your payment didn't go through — this order was not placed."
                      : _statusMessage(order.status),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
                if (order.estimatedDelivery != null &&
                    order.deliveryMode != 'SCHEDULED') ...<Widget>[
                  Gap(8.h),
                  Text(
                    'ETA: ${order.estimatedDelivery!.toIndianDateTime}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
                if (order.deliveryMode == 'SCHEDULED' &&
                    order.scheduledSlotLabel != null) ...<Widget>[
                  Gap(8.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_month_outlined,
                          size: 12.sp,
                          color: Colors.white,
                        ),
                        Gap(4.w),
                        Text(
                          order.scheduledSlotLabel!,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Gap(8.h),
                Text(
                  'Order #${order.orderNumber}',
                  style:
                      AppTextStyles.labelSmall.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusMessage(OrderStatus status) {
    return switch (status) {
      OrderStatus.PENDING => 'We are confirming your order.',
      OrderStatus.CONFIRMED => 'Store has accepted your order.',
      OrderStatus.PREPARING => 'Your groceries are being packed.',
      OrderStatus.PACKED => 'Order packed and ready for rider pickup.',
      OrderStatus.OUT_FOR_DELIVERY => 'Rider is on the way.',
      OrderStatus.DELIVERED => 'Order delivered successfully.',
      OrderStatus.CANCELLED => 'This order has been cancelled.',
      OrderStatus.REFUNDED => 'Your refund has been processed.',
    };
  }

  String _animationForStatus(OrderStatus status) {
    return switch (status) {
      OrderStatus.PENDING => 'assets/animations/order_pending.json',
      OrderStatus.CONFIRMED => 'assets/animations/order_confirmed.json',
      OrderStatus.PREPARING => 'assets/animations/order_preparing.json',
      OrderStatus.PACKED => 'assets/animations/order_packed.json',
      OrderStatus.OUT_FOR_DELIVERY =>
        'assets/animations/order_out_for_delivery.json',
      OrderStatus.DELIVERED => 'assets/animations/order_delivered.json',
      OrderStatus.CANCELLED => 'assets/animations/order_cancelled.json',
      // No dedicated refund animation asset — reuse the cancelled one since
      // both are terminal, non-fulfilled outcomes.
      OrderStatus.REFUNDED => 'assets/animations/order_cancelled.json',
    };
  }
}

/// Shown inside the "Delivery OTP" section while a rider is actively
/// assigned (ACCEPTED/IN_TRANSIT). The customer reads these digits out
/// to the rider on arrival to confirm delivery.
class _DeliveryOtpRow extends StatelessWidget {
  const _DeliveryOtpRow({required this.otp});

  final String otp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.primaryGreenLight,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Text(
              otp,
              style: AppTextStyles.h2.copyWith(
                color: AppColors.primaryGreenDark,
                letterSpacing: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        Gap(12.h),
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.warningOrange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: AppColors.warningOrange.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.info_outline,
                size: 18.sp,
                color: AppColors.warningOrange,
              ),
              Gap(8.w),
              Expanded(
                child: Text(
                  "Don't share this code yet. Only tell it to your delivery "
                  'partner when they arrive at your door — this confirms '
                  'your order was delivered to you.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppTextStyles.h3),
          Gap(12.h),
          child,
        ],
      ),
    );
  }
}

class _TimelineStepper extends StatelessWidget {
  const _TimelineStepper({required this.order});

  final OrderEntity order;

  @override
  Widget build(BuildContext context) {
    final statuses = _buildStatusFlow(order.status);
    final timelineMap = <OrderTimelineType, DateTime>{};
    for (final item in order.timeline) {
      timelineMap[item.type] = item.timestamp;
    }

    final currentType = order.status == OrderStatus.CANCELLED
        ? OrderTimelineType.CANCELLED
        : order.status == OrderStatus.REFUNDED
            ? OrderTimelineType.REFUNDED
            : order.timeline.isNotEmpty
                ? order.timeline.last.type
                : orderTimelineTypeForStatus(order.status);
    final currentIndex = statuses.indexOf(currentType);
    return Column(
      children: List<Widget>.generate(statuses.length, (index) {
        final status = statuses[index];
        final isCurrent = status == currentType;
        final isCompleted = _isCompleted(
          currentIndex: currentIndex,
          index: index,
          status: status,
          orderStatus: order.status,
          timelineMap: timelineMap,
        );
        final isFuture = !isCurrent && !isCompleted;
        final timestamp = timelineMap[status];

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 24.w,
              child: Column(
                children: <Widget>[
                  _TimelineDot(
                    isCurrent: isCurrent,
                    isCompleted: isCompleted,
                    isFuture: isFuture,
                  ),
                  if (index != statuses.length - 1)
                    Container(
                      width: 2.w,
                      height: 34.h,
                      color: isCompleted
                          ? AppColors.primaryGreen
                          : AppColors.borderLight,
                    ),
                ],
              ),
            ),
            Gap(10.w),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: 14.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      status.label,
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isFuture
                            ? AppColors.textTertiary
                            : AppColors.textPrimary,
                      ),
                    ),
                    Gap(2.h),
                    Text(
                      timestamp?.toIndianDateTime ?? 'Waiting',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isFuture
                            ? AppColors.textTertiary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  List<OrderTimelineType> _buildStatusFlow(OrderStatus status) {
    if (status == OrderStatus.CANCELLED) {
      return const <OrderTimelineType>[
        OrderTimelineType.PENDING,
        OrderTimelineType.CONFIRMED,
        OrderTimelineType.PREPARING,
        OrderTimelineType.CANCELLED,
      ];
    }

    if (status == OrderStatus.REFUNDED) {
      // A refund always follows either a cancelled or a delivered order —
      // show whichever one actually happened (from the real timeline data)
      // followed by the refund itself, rather than guessing a fixed path.
      final wasCancelledFirst = order.timeline
          .any((item) => item.type == OrderTimelineType.CANCELLED);
      return wasCancelledFirst
          ? const <OrderTimelineType>[
              OrderTimelineType.PENDING,
              OrderTimelineType.CONFIRMED,
              OrderTimelineType.PREPARING,
              OrderTimelineType.CANCELLED,
              OrderTimelineType.REFUNDED,
            ]
          : const <OrderTimelineType>[
              OrderTimelineType.PENDING,
              OrderTimelineType.CONFIRMED,
              OrderTimelineType.PREPARING,
              OrderTimelineType.PACKED,
              OrderTimelineType.RIDER_ACCEPTED,
              OrderTimelineType.PICKED_UP,
              OrderTimelineType.OUT_FOR_DELIVERY,
              OrderTimelineType.DELIVERED,
              OrderTimelineType.REFUNDED,
            ];
    }

    return const <OrderTimelineType>[
      OrderTimelineType.PENDING,
      OrderTimelineType.CONFIRMED,
      OrderTimelineType.PREPARING,
      OrderTimelineType.PACKED,
      OrderTimelineType.RIDER_ACCEPTED,
      OrderTimelineType.PICKED_UP,
      OrderTimelineType.OUT_FOR_DELIVERY,
      OrderTimelineType.DELIVERED,
    ];
  }

  bool _isCompleted({
    required int currentIndex,
    required int index,
    required OrderTimelineType status,
    required OrderStatus orderStatus,
    required Map<OrderTimelineType, DateTime> timelineMap,
  }) {
    if (orderStatus == OrderStatus.CANCELLED) {
      return timelineMap.containsKey(status) &&
          status != OrderTimelineType.CANCELLED;
    }
    if (orderStatus == OrderStatus.REFUNDED) {
      return timelineMap.containsKey(status) &&
          status != OrderTimelineType.REFUNDED;
    }
    return timelineMap.containsKey(status) || index < currentIndex;
  }
}

class _TimelineDot extends StatelessWidget {
  const _TimelineDot({
    required this.isCurrent,
    required this.isCompleted,
    required this.isFuture,
  });

  final bool isCurrent;
  final bool isCompleted;
  final bool isFuture;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 16.w,
      height: 16.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted || isCurrent
            ? AppColors.primaryGreen
            : AppColors.bgSection,
        border: Border.all(
          color: isFuture ? AppColors.borderLight : AppColors.primaryGreen,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: (isCompleted && !isCurrent)
          ? Icon(
              Icons.check,
              size: 10.sp,
              color: Colors.white,
            )
          : null,
    );

    if (!isCurrent) {
      return dot;
    }

    return dot
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1.1, 1.1),
          duration: 600.ms,
        );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item});

  final OrderItemEntity item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SafeProductImage(
            url: item.thumbnailUrl,
            size: 56.w,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            backgroundColor: AppColors.bgInput,
            iconSize: 22.sp,
          ),
          Gap(10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.name,
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Gap(4.h),
                Text(
                  '${item.quantity} × ${item.unit}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(item.price.toInrCurrency, style: AppTextStyles.bodySmall),
              Gap(4.h),
              Text(
                item.total.toInrCurrency,
                style: AppTextStyles.labelLarge
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceBreakdown extends StatelessWidget {
  const _PriceBreakdown({required this.order});

  final OrderEntity order;

  @override
  Widget build(BuildContext context) {
    const taxAmount = 0.0;
    return Column(
      children: <Widget>[
        _PriceRow(label: 'Subtotal', value: order.subtotal),
        if (order.discount > 0)
          _PriceRow(
            label: order.couponCode == null
                ? 'Discount'
                : 'Coupon (${order.couponCode})',
            value: order.discount,
            prefix: '-',
            valueColor: AppColors.successGreen,
          ),
        _PriceRow(label: 'Delivery fee', value: order.deliveryFee),
        _PriceRow(label: 'Platform fee', value: order.platformFee),
        const _PriceRow(label: 'Tax', value: taxAmount),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: const Divider(height: 1, color: AppColors.divider),
        ),
        _PriceRow(
          label: 'Total',
          value: order.total,
          style: AppTextStyles.h3,
        ),
        if (order.walletAmountUsed > 0) ...<Widget>[
          Gap(8.h),
          _PriceRow(
            label: 'Paid via Wallet',
            value: order.walletAmountUsed,
            prefix: '-',
            valueColor: AppColors.orderViolet,
          ),
          if (order.total - order.walletAmountUsed > 0)
            _PriceRow(
              label: 'Balance due (${_prettyText(order.paymentMethod)})',
              value: order.total - order.walletAmountUsed,
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.prefix = '',
    this.valueColor,
    this.style,
  });

  final String label;
  final double value;
  final String prefix;
  final Color? valueColor;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          Text(
            '$prefix${value.toInrCurrency}',
            style: style ??
                AppTextStyles.labelLarge.copyWith(
                  color: valueColor ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _PaymentInfo extends StatelessWidget {
  const _PaymentInfo({required this.order});

  final OrderEntity order;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _InfoRow(label: 'Method', value: _prettyText(order.paymentMethod)),
        _InfoRow(label: 'Status', value: _prettyText(order.paymentStatus)),
        if (order.walletAmountUsed > 0)
          _InfoRow(
            label: 'Wallet used',
            value: order.walletAmountUsed.toInrCurrency,
            valueColor: AppColors.orderViolet,
          ),
        if (order.razorpayPaymentId != null)
          _InfoRow(
            label: 'Razorpay ID',
            value: order.razorpayPaymentId!,
          ),
      ],
    );
  }

  String _prettyText(String value) {
    return value.trim().toLowerCase().split('_').map((part) {
      if (part.isEmpty) {
        return '';
      }
      return '${part[0].toUpperCase()}${part.substring(1)}';
    }).join(' ');
  }
}

class _AddressInfo extends StatelessWidget {
  const _AddressInfo({required this.order});

  final OrderEntity order;

  @override
  Widget build(BuildContext context) {
    final address = order.deliveryAddress;
    final label = _readString(address, <String>['label'], fallback: 'Address');
    final name = _readString(address, <String>['name']);
    final phone = _readString(address, <String>['phone']);
    final line1 =
        _readString(address, <String>['addressLine1', 'address_line1']);
    final line2 =
        _readString(address, <String>['addressLine2', 'address_line2']);
    final city = _readString(address, <String>['city']);
    final state = _readString(address, <String>['state']);
    final pincode = _readString(address, <String>['pincode']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$label${name.isNotEmpty ? ' • $name' : ''}',
          style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        if (phone.isNotEmpty) ...<Widget>[
          Gap(4.h),
          Text(phone, style: AppTextStyles.bodySmall),
        ],
        Gap(6.h),
        Text(
          <String>[
            line1,
            if (line2.isNotEmpty) line2,
            <String>[city, state, pincode]
                .where((item) => item.isNotEmpty)
                .join(', '),
          ].where((item) => item.isNotEmpty).join(', '),
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }

  String _readString(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return fallback;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: AppTextStyles.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
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
    final (
      Color accent,
      Color surface,
      IconData icon,
      String title,
      String subtitle
    ) = switch (request.status) {
      'PENDING' => (
          AppColors.orderViolet,
          AppColors.orderVioletSurface,
          PhosphorIcons.clockCountdown,
          'Refund request pending',
          "We've received your request — our team will review it and connect with you within 24 hours.",
        ),
      'APPROVED' => (
          AppColors.primaryGreen,
          AppColors.primaryGreenLight,
          PhosphorIcons.checkCircleFill,
          'Refund approved',
          request.refundAmount != null
              ? '${request.refundAmount!.toInrCurrency} credited to your ${request.refundTo == 'original' ? 'original payment method' : 'wallet'}.'
              : 'Your refund has been processed.',
        ),
      'REJECTED' => (
          AppColors.errorRed,
          const Color(0xFFFEF2F2),
          PhosphorIcons.xCircleFill,
          'Refund request rejected',
          (request.adminNote ?? '').trim().isNotEmpty
              ? request.adminNote!.trim()
              : 'Our team reviewed this request and it was not approved.',
        ),
      _ => (
          AppColors.textSecondary,
          AppColors.bgSection,
          PhosphorIcons.prohibit,
          'Refund request cancelled',
          "You cancelled this request. You're free to raise a new one if the issue is still unresolved.",
        ),
    };

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PhosphorIcon(icon, size: 20.sp, color: accent),
              Gap(10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    Gap(4.h),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((request.description).trim().isNotEmpty) ...<Widget>[
            Gap(8.h),
            Text(
              '"${request.description.trim()}"',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (request.isPending) ...<Widget>[
            Gap(10.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onCancel,
                child: const Text('Cancel Request'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderActions extends StatelessWidget {
  const _OrderActions({
    required this.order,
    required this.isCancelling,
    required this.isReordering,
    required this.isDownloadingInvoice,
    required this.onCancel,
    required this.onReorder,
    required this.onDownloadInvoice,
    required this.onWriteReview,
    required this.onRequestRefund,
    this.canRequestRefund = true,
  });

  final OrderEntity order;
  final bool isCancelling;
  final bool isReordering;
  final bool isDownloadingInvoice;
  final VoidCallback onCancel;
  final VoidCallback onReorder;
  final VoidCallback onDownloadInvoice;
  final VoidCallback onWriteReview;
  final VoidCallback onRequestRefund;

  /// False while a non-cancelled refund request already exists for this
  /// order — the status card above is the single place to act on it then,
  /// so this button steps aside rather than offering a duplicate path in.
  final bool canRequestRefund;

  @override
  Widget build(BuildContext context) {
    switch (order.status) {
      case OrderStatus.PENDING:
      case OrderStatus.CONFIRMED:
      case OrderStatus.PREPARING:
        return FilledButton(
          onPressed: isCancelling ? null : onCancel,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.errorRed,
            minimumSize: Size.fromHeight(46.h),
          ),
          child: isCancelling
              ? SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Cancel Order'),
        );
      case OrderStatus.DELIVERED:
        return Column(
          children: <Widget>[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isDownloadingInvoice ? null : onDownloadInvoice,
                icon: isDownloadingInvoice
                    ? SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : PhosphorIcon(PhosphorIcons.filePdf, size: 16.sp),
                label: const Text('Download Invoice'),
              ),
            ),
            Gap(8.h),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onWriteReview,
                    child: const Text('Write Review'),
                  ),
                ),
                Gap(8.w),
                Expanded(
                  child: FilledButton(
                    onPressed: isReordering ? null : onReorder,
                    child: isReordering
                        ? SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.textOnGreen,
                              ),
                            ),
                          )
                        : const Text('Re-order'),
                  ),
                ),
              ],
            ),
            if (canRequestRefund) ...<Widget>[
              Gap(8.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onRequestRefund,
                  icon: PhosphorIcon(PhosphorIcons.receipt, size: 16.sp),
                  label: const Text('Request Refund'),
                ),
              ),
            ],
          ],
        );
      case OrderStatus.CANCELLED:
      case OrderStatus.REFUNDED:
        return Column(
          children: <Widget>[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isDownloadingInvoice ? null : onDownloadInvoice,
                icon: isDownloadingInvoice
                    ? SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : PhosphorIcon(PhosphorIcons.filePdf, size: 16.sp),
                label: const Text('Download Invoice'),
              ),
            ),
            Gap(8.h),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isReordering ? null : onReorder,
                child: isReordering
                    ? SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.textOnGreen,
                          ),
                        ),
                      )
                    : const Text('Re-order'),
              ),
            ),
          ],
        );
      case OrderStatus.PACKED:
      case OrderStatus.OUT_FOR_DELIVERY:
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.push('/orders/${order.id}/track'),
            icon: PhosphorIcon(PhosphorIcons.navigationArrow, size: 16.sp),
            label: const Text('Track Order'),
          ),
        );
    }
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
            PhosphorIcon(
              PhosphorIcons.warningCircle,
              size: 40.sp,
              color: AppColors.warningOrange,
            ),
            Gap(10.h),
            Text(
              message,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            Gap(12.h),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
