import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:bakaloo_flutter_app/shared/widgets/safe_product_image.dart';

/// A row of small product thumbnails followed by a trailing "+N more" pill.
///
/// Matches the reference order card: always shows up to [maxVisible] item
/// thumbnails and a "+N more" pill (including "+0 more"). The pill count is the
/// number of distinct line items beyond the visible thumbnails.
class OrderItemThumbRow extends StatelessWidget {
  const OrderItemThumbRow({
    required this.items,
    this.maxVisible = 3,
    super.key,
  });

  final List<OrderItemEntity> items;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final thumbSize = 36.w;
    final gap = 8.w;

    final visible = items.take(maxVisible).toList(growable: false);
    final extra = items.length - visible.length;

    return SizedBox(
      height: thumbSize,
      child: Row(
        children: <Widget>[
          for (var i = 0; i < visible.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: gap),
            _Thumb(url: visible[i].thumbnailUrl, size: thumbSize),
          ],
          SizedBox(width: gap),
          _MorePill(count: extra < 0 ? 0 : extra, size: thumbSize),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.orderThumbBorder),
      ),
      padding: EdgeInsets.all(3.w),
      child: SafeProductImage(
        url: url,
        size: size - 6.w,
        borderRadius: BorderRadius.circular(8.r),
        fit: BoxFit.contain,
        backgroundColor: Colors.white,
        iconSize: 14.sp,
      ),
    );
  }
}

class _MorePill extends StatelessWidget {
  const _MorePill({required this.count, required this.size});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.orderVioletSurface,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Text(
        '+$count more',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.orderViolet,
          height: 1.1,
        ),
      ),
    );
  }
}
