import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';

class RatingBadge extends StatelessWidget {
  const RatingBadge({
    required this.rating,
    required this.count,
    super.key,
  });

  final double rating;
  final int count;

  String get _formattedCount {
    if (count < 1000) {
      return '$count';
    }

    final value = count / 1000;
    final formatted = value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '${formatted}k';
  }

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0x14000000),
            blurRadius: 6.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 20.w,
            height: 20.w,
            decoration: const BoxDecoration(
              color: AppColors.pdViolet,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: PhosphorIcon(
                PhosphorIcons.starFill,
                size: 11.sp,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          // Below 11 reviews, the count reads as "barely reviewed" and
          // undersells the product — only the average star shows until
          // there's enough reviews for the count to be a real trust signal.
          if (count > 10) ...<Widget>[
            SizedBox(width: 6.w),
            Container(
              width: 1,
              height: 14.h,
              color: const Color(0xFFE0E0E0),
            ),
            SizedBox(width: 6.w),
            Text(
              _formattedCount,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF999999),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
