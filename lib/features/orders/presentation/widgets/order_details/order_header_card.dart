import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/utils/extensions/datetime_extensions.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_details/order_detail_palette.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_status_pill.dart';

/// Order number, placed-at timestamp and status chip — item 2 of the Order
/// Details screen. The secondary "Reorder" pill only appears once the order
/// has actually finished (delivered/cancelled/refunded); offering it on a
/// still-cooking order would compete with the real primary action for that
/// state (Cancel/Track — see [StickyOrderActions]).
class OrderHeaderCard extends StatelessWidget {
  const OrderHeaderCard({
    required this.order,
    required this.onReorder,
    required this.isReordering,
    super.key,
  });

  final OrderEntity order;
  final VoidCallback onReorder;
  final bool isReordering;

  bool get _canReorderHere =>
      order.status == OrderStatus.DELIVERED ||
      order.status == OrderStatus.CANCELLED ||
      order.status == OrderStatus.REFUNDED;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: OrderDetailPalette.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: OrderDetailPalette.border),
        boxShadow: const <BoxShadow>[OrderDetailPalette.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Text(
                  'Order Details',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: OrderDetailPalette.textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              OrderStatusPill(
                status: order.status,
                isPaymentFailed: order.isPaymentFailed,
              ),
            ],
          ),
          Gap(6.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  order.orderNumber,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w800,
                    color: OrderDetailPalette.textPrimary,
                    height: 1.15,
                  ),
                ),
              ),
              if (_canReorderHere) ...<Widget>[
                Gap(10.w),
                _ReorderPill(onPressed: onReorder, isLoading: isReordering),
              ],
            ],
          ),
          Gap(4.h),
          Text(
            'Placed on ${order.createdAt.toIndianDateTime}',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              color: OrderDetailPalette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReorderPill extends StatelessWidget {
  const _ReorderPill({required this.onPressed, required this.isLoading});

  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: OrderDetailPalette.primaryRed,
        side: const BorderSide(color: OrderDetailPalette.primaryRed),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100.r),
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: isLoading
          ? SizedBox(
              width: 14.w,
              height: 14.w,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  OrderDetailPalette.primaryRed,
                ),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.replay_rounded, size: 14.sp),
                Gap(4.w),
                Text(
                  'Reorder',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Item 5 — the status/summary banner directly under the header. Copy and
/// icon are keyed off the same real `OrderStatus` the rest of the screen
/// uses; the trailing "Buy Again" CTA only shows once there's nothing left
/// to track or cancel (delivered/cancelled/refunded), mirroring
/// [OrderHeaderCard]'s reorder-pill gating so the two never disagree.
class OrderStatusBanner extends StatelessWidget {
  const OrderStatusBanner({
    required this.order,
    required this.onReorder,
    required this.isReordering,
    super.key,
  });

  final OrderEntity order;
  final VoidCallback onReorder;
  final bool isReordering;

  @override
  Widget build(BuildContext context) {
    final (
      IconData icon,
      Color accent,
      Color surface,
      String message,
    ) = _presentationFor(order);

    final showBuyAgain = order.status == OrderStatus.DELIVERED ||
        order.status == OrderStatus.CANCELLED ||
        order.status == OrderStatus.REFUNDED;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40.w,
            height: 40.w,
            decoration: const BoxDecoration(
              color: OrderDetailPalette.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 20.sp),
          ),
          Gap(12.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w600,
                color: OrderDetailPalette.textPrimary,
                height: 1.35,
              ),
            ),
          ),
          if (showBuyAgain) ...<Widget>[
            Gap(10.w),
            SizedBox(
              height: 34.h,
              child: FilledButton(
                onPressed: isReordering ? null : onReorder,
                style: FilledButton.styleFrom(
                  backgroundColor: OrderDetailPalette.ctaRed,
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100.r),
                  ),
                ),
                child: isReordering
                    ? SizedBox(
                        width: 14.w,
                        height: 14.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Buy Again',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  (IconData, Color, Color, String) _presentationFor(OrderEntity order) {
    if (order.isPaymentFailed) {
      return (
        PhosphorIcons.xCircleFill,
        OrderDetailPalette.ctaRed,
        OrderDetailPalette.errorSurface,
        "Your payment didn't go through — this order was not placed.",
      );
    }
    return switch (order.status) {
      OrderStatus.PENDING => (
          PhosphorIcons.clockCountdown,
          OrderDetailPalette.primaryRed,
          OrderDetailPalette.primaryRedSurface,
          'We are confirming your order.',
        ),
      OrderStatus.CONFIRMED => (
          PhosphorIcons.checkCircle,
          OrderDetailPalette.primaryRed,
          OrderDetailPalette.primaryRedSurface,
          'Store has accepted your order.',
        ),
      OrderStatus.PREPARING => (
          PhosphorIcons.cookingPot,
          OrderDetailPalette.primaryRed,
          OrderDetailPalette.primaryRedSurface,
          'Your order is being packed.',
        ),
      OrderStatus.PACKED => (
          PhosphorIcons.package,
          OrderDetailPalette.primaryRed,
          OrderDetailPalette.primaryRedSurface,
          'Order packed and ready for rider pickup.',
        ),
      OrderStatus.OUT_FOR_DELIVERY => (
          PhosphorIcons.truck,
          OrderDetailPalette.primaryRed,
          OrderDetailPalette.primaryRedSurface,
          'Rider is on the way.',
        ),
      OrderStatus.DELIVERED => (
          PhosphorIcons.packageFill,
          OrderDetailPalette.successGreen,
          OrderDetailPalette.successGreenSurface,
          'Your order has been delivered. Thanks for choosing FreshCuts!',
        ),
      OrderStatus.CANCELLED => (
          PhosphorIcons.xCircleFill,
          OrderDetailPalette.ctaRed,
          OrderDetailPalette.errorSurface,
          'This order has been cancelled.',
        ),
      OrderStatus.REFUNDED => (
          PhosphorIcons.arrowCounterClockwise,
          OrderDetailPalette.primaryRed,
          OrderDetailPalette.primaryRedSurface,
          'Your refund has been processed.',
        ),
    };
  }
}
