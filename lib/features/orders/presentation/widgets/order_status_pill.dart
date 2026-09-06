import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';

/// Small pill with a leading dot showing the order status (e.g. "Confirmed").
class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({
    required this.status,
    this.isPaymentFailed = false,
    super.key,
  });

  final OrderStatus status;

  // Set from OrderEntity.isPaymentFailed — a CANCELLED order whose payment
  // actually expired/failed shows "Failed" instead of "Cancelled" (same red
  // palette; the label is what disambiguates), so it doesn't read as a
  // deliberate cancellation.
  final bool isPaymentFailed;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(status);
    final label = isPaymentFailed ? 'Failed' : status.label;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(
              color: palette.foreground,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: palette.foreground,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  static _StatusPalette _paletteFor(OrderStatus status) {
    return switch (status) {
      OrderStatus.PENDING => const _StatusPalette(
          AppColors.orderStatusAmber,
          AppColors.orderStatusAmberBg,
        ),
      OrderStatus.CONFIRMED => const _StatusPalette(
          AppColors.orderStatusBlue,
          AppColors.orderStatusBlueBg,
        ),
      OrderStatus.PREPARING || OrderStatus.PACKED => const _StatusPalette(
          AppColors.orderStatusTeal,
          AppColors.orderStatusTealBg,
        ),
      OrderStatus.OUT_FOR_DELIVERY => const _StatusPalette(
          AppColors.orderStatusGreen,
          AppColors.orderStatusGreenBg,
        ),
      OrderStatus.DELIVERED => const _StatusPalette(
          AppColors.orderStatusGreen,
          AppColors.orderStatusGreenBg,
        ),
      OrderStatus.CANCELLED => const _StatusPalette(
          AppColors.orderStatusRed,
          AppColors.orderStatusRedBg,
        ),
      OrderStatus.REFUNDED => const _StatusPalette(
          AppColors.orderStatusRed,
          AppColors.orderStatusRedBg,
        ),
    };
  }
}

class _StatusPalette {
  const _StatusPalette(this.foreground, this.background);

  final Color foreground;
  final Color background;
}
