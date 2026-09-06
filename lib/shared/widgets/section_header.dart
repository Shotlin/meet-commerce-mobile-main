import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.actionLabel = 'See all',
    this.onTap,
    this.padding,
    super.key,
  });

  final String title;
  final String actionLabel;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: AppDimensions.screenPaddingHorizontal.w,
          ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.h2.copyWith(fontSize: 18.sp),
            ),
          ),
          if (onTap != null)
            TextButton(
              onPressed: onTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    actionLabel,
                    style: AppTextStyles.buttonSmall.copyWith(
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing4),
                  PhosphorIcon(
                    PhosphorIcons.arrowRight,
                    size: 16,
                    color: AppColors.primaryGreen,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
