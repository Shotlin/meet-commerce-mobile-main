import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

class LogoutSheet extends ConsumerWidget {
  const LogoutSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgCard,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20.r),
        ),
      ),
      builder: (context) => const LogoutSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 2.h, 20.w, 22.h),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Log out?',
              style: AppTextStyles.h2,
            ),
            Gap(10.h),
            Text(
              'Are you sure you want to log out?',
              style: AppTextStyles.bodyMedium,
            ),
            Gap(18.h),
            SizedBox(
              height: 48.h,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.errorRed,
                ),
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).logout();
                  if (!context.mounted) {
                    return;
                  }
                  context.go(RouteNames.phone);
                },
                child: Text(
                  'Log Out',
                  style: AppTextStyles.buttonLarge.copyWith(
                    color: AppColors.textOnGreen,
                  ),
                ),
              ),
            ),
            Gap(6.h),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: AppTextStyles.buttonMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
