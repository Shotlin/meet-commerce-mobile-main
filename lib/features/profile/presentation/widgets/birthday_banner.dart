import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';

class BirthdayBanner extends StatelessWidget {
  const BirthdayBanner({
    required this.birthday,
    required this.onSelectBirthday,
    super.key,
  });

  final DateTime? birthday;
  final ValueChanged<DateTime> onSelectBirthday;

  @override
  Widget build(BuildContext context) {
    if (birthday != null) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final selected = await showDatePicker(
          context: context,
          initialDate: DateTime(now.year - 20, now.month, now.day),
          firstDate: DateTime(1950),
          lastDate: now,
        );
        if (selected != null) {
          onSelectBirthday(selected);
        }
      },
      borderRadius: BorderRadius.circular(AppDimensions.radiusLg.r),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[
              Color(0xFFFFF4D7),
              Color(0xFFFFE9A5),
            ],
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg.r),
          boxShadow: const <BoxShadow>[AppShadows.cardShadow],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Add your birthday',
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 16.sp,
                      ),
                    ),
                    Gap(4.h),
                    Text(
                      'Enter details >',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 48.r,
                width: 48.r,
                decoration: BoxDecoration(
                  color: AppColors.bgCard.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: PhosphorIcon(
                    PhosphorIcons.cake,
                    size: 24.sp,
                    color: AppColors.accentYellowDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
