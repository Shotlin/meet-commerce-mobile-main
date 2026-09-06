import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';

/// A premium full-screen state (offline, location unavailable, etc.).
///
/// Layout: a full-bleed illustration anchored to the top (bleeding under the
/// status bar) with a white card pinned to the bottom. The card has rounded
/// top corners + square bottom corners and overlaps the illustration. Inside:
/// a circular icon badge, title, subtitle and up to two action buttons.
///
/// This is the canonical "box" style shared by the offline and
/// location-unavailable screens so they stay visually identical.
class BakalooStateScreen extends StatelessWidget {
  const BakalooStateScreen({
    required this.illustrationAsset,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.backgroundColor = const Color(0xFFF6EFEA),
    this.cardHeightFactor = 0.42,
    super.key,
  });

  final String illustrationAsset;
  final PhosphorIconData icon;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Color backgroundColor;
  final double cardHeightFactor;

  @override
  Widget build(BuildContext context) {
    // Bleed the illustration under the status bar (no opaque black band) and
    // use dark icons since the illustration top is light.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Material(
        color: backgroundColor,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Full-bleed illustration anchored to the top.
            Align(
              alignment: Alignment.topCenter,
              child: Image.asset(
                illustrationAsset,
                fit: BoxFit.cover,
                width: double.infinity,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stackTrace) =>
                    ColoredBox(color: backgroundColor),
              ),
            ),
            // Rounded-top white card pinned to the bottom, overlapping the
            // illustration.
            Align(
              alignment: Alignment.bottomCenter,
              child: _StateCard(heightFactor: cardHeightFactor),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _StateCardContent(
                icon: icon,
                title: title,
                subtitle: subtitle,
                primaryLabel: primaryLabel,
                onPrimary: onPrimary,
                secondaryLabel: secondaryLabel,
                onSecondary: onSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The white sheet (rounded top-left + top-right corners) behind the content.
class _StateCard extends StatelessWidget {
  const _StateCard({required this.heightFactor});

  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: heightFactor.sh,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0x1A000000),
            blurRadius: 24.r,
            offset: Offset(0, -6.h),
          ),
        ],
      ),
    );
  }
}

class _StateCardContent extends StatelessWidget {
  const _StateCardContent({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final PhosphorIconData icon;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24.w, 22.h, 24.w, 18.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64.w,
              height: 64.w,
              decoration: const BoxDecoration(
                color: AppColors.orderVioletSurface,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: PhosphorIcon(
                  icon,
                  size: 30.sp,
                  color: AppColors.orderViolet,
                ),
              ),
            ),
            Gap(16.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1A1A),
                height: 1.2,
              ),
            ),
            Gap(8.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            Gap(22.h),
            BakalooStateButton(
              label: primaryLabel,
              onTap: onPrimary,
              filled: true,
            ),
            if (secondaryLabel != null && onSecondary != null) ...<Widget>[
              Gap(12.h),
              BakalooStateButton(
                label: secondaryLabel!,
                onTap: onSecondary!,
                filled: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared filled/outlined action button used by Bakaloo state screens.
class BakalooStateButton extends StatelessWidget {
  const BakalooStateButton({
    required this.label,
    required this.onTap,
    required this.filled,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.orderViolet : Colors.white,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          width: double.infinity,
          height: 52.h,
          alignment: Alignment.center,
          decoration: filled
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(14.r),
                  border:
                      Border.all(color: AppColors.orderViolet, width: 1.4),
                ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : AppColors.orderViolet,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
