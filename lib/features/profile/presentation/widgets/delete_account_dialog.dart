import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';

class DeleteAccountDialog extends StatelessWidget {
  const DeleteAccountDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => const DeleteAccountDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Delete Account',
        style: AppTextStyles.h2.copyWith(
          color: AppColors.errorRed,
        ),
      ),
      content: Text(
        'This will permanently delete your account and all data. This action cannot be undone.',
        style: AppTextStyles.bodyMedium.copyWith(
          fontSize: 14.sp,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: AppTextStyles.buttonMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.errorRed,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            'Delete',
            style: AppTextStyles.buttonMedium.copyWith(
              color: AppColors.textOnGreen,
            ),
          ),
        ),
      ],
    );
  }
}
