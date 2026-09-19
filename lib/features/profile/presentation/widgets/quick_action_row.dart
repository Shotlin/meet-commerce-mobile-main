import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';

class QuickActionRow extends StatelessWidget {
  const QuickActionRow({
    required this.onOrdersTap,
    required this.onWalletTap,
    required this.onHelpTap,
    super.key,
  });

  final VoidCallback onOrdersTap;
  final VoidCallback onWalletTap;
  final VoidCallback onHelpTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _QuickActionTile(
            icon: PhosphorIcons.package,
            label: 'Your orders',
            onTap: onOrdersTap,
          ),
        ),
        Gap(10.w),
        Expanded(
          child: _QuickActionTile(
            icon: PhosphorIcons.wallet,
            label: 'Bakaloo Money',
            onTap: onWalletTap,
          ),
        ),
        Gap(10.w),
        Expanded(
          child: _QuickActionTile(
            icon: PhosphorIcons.question,
            label: 'Need help?',
            onTap: onHelpTap,
          ),
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusLg.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 2.h),
        child: Column(
          children: <Widget>[
            Container(
              height: 64.r,
              width: 64.r,
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: const <BoxShadow>[AppShadows.cardShadow],
              ),
              child: Center(
                child: PhosphorIcon(
                  icon,
                  size: 28.sp,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
            Gap(8.h),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 11.sp,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
