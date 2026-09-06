import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';

/// Bakaloo violet price tag.
///
/// Renders the effective price inside a soft, violet-outlined rounded card
/// with a light lavender fill — matching the dedicated product screen design.
class RetroPriceBadge extends StatelessWidget {
  const RetroPriceBadge({
    required this.price,
    this.fontSize,
    super.key,
  });

  final double price;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final resolvedFontSize = fontSize ?? 20.sp;
    final horizontalPadding = (resolvedFontSize * 0.7).clamp(10.0, 16.0);
    final verticalPadding = (resolvedFontSize * 0.5).clamp(6.0, 12.0);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding.w,
        vertical: verticalPadding.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.pdVioletSurface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.pdViolet,
          width: 1.5,
        ),
      ),
      child: Text(
        '₹${price.toStringAsFixed(0)}',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: resolvedFontSize,
          fontWeight: FontWeight.w800,
          color: AppColors.pdVioletDark,
          height: 1.1,
        ),
      ),
    );
  }
}
