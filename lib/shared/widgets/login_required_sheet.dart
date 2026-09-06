import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';

class LoginRequiredSheet extends StatelessWidget {
  const LoginRequiredSheet({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final shouldContinue = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return LoginRequiredSheet(
          title: title,
          message: message,
        );
      },
    );

    return shouldContinue ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            boxShadow: const <BoxShadow>[AppShadows.floatingShadow],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 18.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 44.w,
                    height: 5.h,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusFull,
                      ),
                    ),
                  ),
                ),
                Gap(18.h),
                Row(
                  children: <Widget>[
                    Container(
                      width: 48.w,
                      height: 48.w,
                      decoration: BoxDecoration(
                        color: AppColors.orderVioletSurface,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                      ),
                      child: Center(
                        child: PhosphorIcon(
                          PhosphorIcons.lockKeyFill,
                          color: AppColors.orderViolet,
                          size: 22.sp,
                        ),
                      ),
                    ),
                    Gap(14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(title, style: AppTextStyles.h2),
                          Gap(4.h),
                          Text(
                            message,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Gap(18.h),
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: AppColors.orderVioletSurface,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusMd,
                    ),
                    border: Border.all(color: AppColors.orderVioletBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      PhosphorIcon(
                        PhosphorIcons.shieldCheckFill,
                        color: AppColors.orderViolet,
                        size: 20.sp,
                      ),
                      Gap(10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Your security is our priority.',
                              style: AppTextStyles.labelLarge.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Gap(3.h),
                            Text(
                              'We protect your information and ensure a safe shopping experience.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Gap(10.w),
                      PhosphorIcon(
                        PhosphorIcons.sparkleFill,
                        color: AppColors.orderViolet,
                        size: 16.sp,
                      ),
                    ],
                  ),
                ),
                Gap(18.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Continue to Login'),
                  ),
                ),
                Gap(10.h),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Not now'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
