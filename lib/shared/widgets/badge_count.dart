import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';

class BadgeCount extends StatelessWidget {
  const BadgeCount({
    required this.count,
    super.key,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    final label = count > 99 ? '99+' : '$count';
    final compact = label.length == 1;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 0 : 5.w,
        vertical: 1.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.errorRed,
        borderRadius: BorderRadius.circular(10.r),
      ),
      constraints: BoxConstraints(
        minWidth: 18.w,
        minHeight: 18.h,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 9.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
