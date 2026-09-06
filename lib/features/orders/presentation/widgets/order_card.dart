import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/datetime_extensions.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_status_pill.dart';
import 'package:bakaloo_flutter_app/shared/widgets/safe_product_image.dart';

/// Flat, single-glance order card — image, order#/date, product line,
/// status pill and one contextual action button.
class OrderCard extends StatelessWidget {
  const OrderCard({
    required this.order,
    required this.isCancelling,
    required this.isReordering,
    required this.onTap,
    required this.onTrack,
    required this.onCancel,
    required this.onReorder,
    required this.onViewDetails,
    super.key,
  });

  final OrderEntity order;
  final bool isCancelling;
  final bool isReordering;
  final VoidCallback onTap;
  final VoidCallback onTrack;
  final VoidCallback onCancel;
  final VoidCallback onReorder;
  final VoidCallback onViewDetails;

  String get _productLine {
    if (order.items.isEmpty) {
      return 'Order items';
    }
    final first = order.items.first.name;
    final extra = order.items.length - 1;
    return extra > 0 ? '$first +$extra more' : first;
  }

  /// A single-item order shows that item's own qty/unit/price (matches the
  /// reference exactly); a multi-item order can't — there's no one
  /// qty/price to show — so it falls back to a total item count and the
  /// order total instead.
  String get _quantityLine {
    if (order.items.length == 1) {
      final item = order.items.first;
      return '${item.quantity} ${item.unit} • ${item.price.toInrCurrency}';
    }
    final itemCount = order.itemCount;
    return '$itemCount item${itemCount == 1 ? '' : 's'} • ${order.total.toInrCurrency}';
  }

  String? get _heroImageUrl {
    for (final item in order.items) {
      if (item.thumbnailUrl != null && item.thumbnailUrl!.trim().isNotEmpty) {
        return item.thumbnailUrl;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F7F9),
      borderRadius: BorderRadius.circular(18.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SafeProductImage(
                url: _heroImageUrl,
                size: 84.w,
                borderRadius: BorderRadius.circular(14.r),
                fit: BoxFit.cover,
                backgroundColor: Colors.white,
                iconSize: 28.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Order #${order.orderNumber}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          order.createdAt.toIndianDateTime,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _productLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      _quantityLine,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: <Widget>[
                        OrderStatusPill(
                          status: order.status,
                          isPaymentFailed: order.isPaymentFailed,
                        ),
                        const Spacer(),
                        _ActionButton(
                          status: order.status,
                          isCancelling: isCancelling,
                          isReordering: isReordering,
                          onTrack: onTrack,
                          onReorder: onReorder,
                          onViewDetails: onViewDetails,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.status,
    required this.isCancelling,
    required this.isReordering,
    required this.onTrack,
    required this.onReorder,
    required this.onViewDetails,
  });

  final OrderStatus status;
  final bool isCancelling;
  final bool isReordering;
  final VoidCallback onTrack;
  final VoidCallback onReorder;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final (String label, VoidCallback onTap, bool isLoading) = switch (status) {
      OrderStatus.PENDING ||
      OrderStatus.CONFIRMED ||
      OrderStatus.PREPARING ||
      OrderStatus.PACKED ||
      OrderStatus.OUT_FOR_DELIVERY =>
        ('Track Order', onTrack, false),
      OrderStatus.DELIVERED => ('Buy Again', onReorder, isReordering),
      OrderStatus.CANCELLED || OrderStatus.REFUNDED => (
          'View Details',
          onViewDetails,
          false
        ),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(100.r),
        child: Container(
          height: 34.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100.r),
            border: Border.all(color: AppColors.brandRed, width: 1.3),
          ),
          child: isLoading
              ? SizedBox(
                  width: 15.w,
                  height: 15.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.brandRed,
                    ),
                  ),
                )
              : Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandRed,
                  ),
                ),
        ),
      ),
    );
  }
}
