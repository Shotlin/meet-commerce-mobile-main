import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/shared/providers/theme_provider.dart';

/// Appearance row with a Light / Dark segmented control (violet active state),
/// styled to sit inside the ACCOUNT SETTINGS menu card.
class AppearanceToggle extends ConsumerWidget {
  const AppearanceToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return SizedBox(
      height: 56.h,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Row(
          children: <Widget>[
            Container(
              width: 36.w,
              height: 36.w,
              decoration: const BoxDecoration(
                color: Color(0xFFF4F4F7),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: PhosphorIcon(
                  isDark
                      ? PhosphorIcons.moon
                      : PhosphorIcons.sun,
                  size: 18.sp,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Gap(12.w),
            Expanded(
              child: Text(
                'Appearance / Theme',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontSize: 14.5.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            _SegmentedTheme(
              isDark: isDark,
              onSelect: (mode) =>
                  ref.read(themeModeProvider.notifier).setThemeMode(mode),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedTheme extends StatelessWidget {
  const _SegmentedTheme({required this.isDark, required this.onSelect});

  final bool isDark;
  final ValueChanged<ThemeMode> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F0F6),
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Segment(
            label: 'Light',
            selected: !isDark,
            onTap: () => onSelect(ThemeMode.light),
          ),
          _Segment(
            label: 'Dark',
            selected: isDark,
            onTap: () => onSelect(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.orderViolet : Colors.transparent,
          borderRadius: BorderRadius.circular(100.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
