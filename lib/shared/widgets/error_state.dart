import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';

class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.message,
    this.title = 'Something went wrong',
    this.onRetry,
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.error_outline,
              size: 56,
              color: AppColors.errorRed,
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
            if (onRetry != null) ...<Widget>[
              const Gap(AppDimensions.spacing20),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
