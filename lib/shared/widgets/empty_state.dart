import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:lottie/lottie.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    this.animationAsset = 'assets/animations/empty_cart.json',
    this.buttonLabel,
    this.onPressed,
    super.key,
  });

  final String title;
  final String message;
  final String animationAsset;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: 180.h,
              child: Lottie.asset(
                animationAsset,
                repeat: false,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.inbox_outlined,
                    size: 80.sp,
                    color: AppColors.textTertiary,
                  );
                },
              ),
            ),
            const Gap(AppDimensions.spacing16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.h2,
            ),
            const Gap(AppDimensions.spacing8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            if (buttonLabel != null && onPressed != null) ...<Widget>[
              const Gap(AppDimensions.spacing20),
              ElevatedButton(
                onPressed: onPressed,
                child: Text(buttonLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
