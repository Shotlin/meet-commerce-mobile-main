import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/network/app_availability_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';

class AppAvailabilityGate extends ConsumerWidget {
  const AppAvailabilityGate({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(appAvailabilityProvider);

    return Stack(
      children: <Widget>[
        child,
        if (status == AppAvailabilityStatus.offline)
          Positioned.fill(
            child: _OfflineScreen(
              onRetry: () => ref.read(appAvailabilityProvider.notifier).retry(),
              onBrowseSaved: () =>
                  ref.read(appAvailabilityProvider.notifier).browseOffline(),
            ),
          )
        else if (status == AppAvailabilityStatus.serviceUnavailable)
          Positioned.fill(
            child: _ServiceUnavailableBlocker(
              onRetry: () => ref.read(appAvailabilityProvider.notifier).retry(),
            ),
          ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Offline screen — shown full-screen (overlaid above whatever page the
// customer was on) the moment device connectivity drops, from
// AppAvailabilityGate wrapping the whole app. The retry/check buttons re-run
// the same real connectivity check (there's only one honest way to "check the
// connection" from inside the app); the saved-items action intentionally
// dismisses the overlay without claiming that live commerce is available.
// ───────────────────────────────────────────────────────────────────────────
class _OfflineScreen extends StatelessWidget {
  const _OfflineScreen({
    required this.onRetry,
    required this.onBrowseSaved,
  });

  final VoidCallback onRetry;
  final VoidCallback onBrowseSaved;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFCFCFE),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(top: 12.h, bottom: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Text(
                  'Bakaloo',
                  style: TextStyle(
                    color: AppColors.brandRed,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Gap(8.h),
              Image.asset(
                'assets/images/bakaloo-offline-state-illustration.png',
                width: double.infinity,
                fit: BoxFit.fitWidth,
              ),
              Gap(12.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 21.sp,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          color: const Color(0xFF1A1A1A),
                        ),
                        children: <TextSpan>[
                          const TextSpan(text: 'No internet\n'),
                          TextSpan(
                            text: 'connection',
                            style: TextStyle(color: AppColors.brandRed),
                          ),
                        ],
                      ),
                    ),
                    Gap(10.h),
                    Text(
                      'Please check your network and try again. Fresh stock, '
                      'delivery and checkout need an active connection. You '
                      'can still browse items saved on this device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    Gap(24.h),
                    _OfflineButton(
                      label: 'Try Again',
                      icon: PhosphorIcons.arrowClockwiseBold,
                      filled: true,
                      onTap: onRetry,
                    ),
                    Gap(12.h),
                    _OfflineButton(
                      label: 'Check Connection',
                      icon: PhosphorIcons.wifiHighBold,
                      filled: false,
                      onTap: onRetry,
                    ),
                    Gap(12.h),
                    _OfflineButton(
                      label: 'Browse saved items',
                      icon: PhosphorIcons.package,
                      filled: false,
                      onTap: onBrowseSaved,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineButton extends StatelessWidget {
  const _OfflineButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final PhosphorIconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: filled ? AppColors.brandRed : Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28.r),
          child: Container(
            width: double.infinity,
            height: 52.h,
            alignment: Alignment.center,
            decoration: filled
                ? null
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(28.r),
                    border: Border.all(
                      color: const Color(0xFFDDDDDD),
                      width: 1.2,
                    ),
                  ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                PhosphorIcon(
                  icon,
                  size: 18.sp,
                  color: filled ? Colors.white : const Color(0xFF1A1A1A),
                ),
                Gap(8.w),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w700,
                    color: filled ? Colors.white : const Color(0xFF1A1A1A),
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

// ───────────────────────────────────────────────────────────────────────────
// Service-unavailable blocker — static illustration (no Rive dependency: its
// native renderer isn't built for 16 KB memory pages and Play Console treats
// that as a release-blocking error, not just a recommendation).
// ───────────────────────────────────────────────────────────────────────────
class _ServiceUnavailableBlocker extends StatelessWidget {
  const _ServiceUnavailableBlocker({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F3F3),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final illustrationSize =
                (constraints.maxWidth * 0.72).clamp(240.0, 320.0);

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                children: <Widget>[
                  const Spacer(flex: 2),
                  SizedBox(
                    width: illustrationSize,
                    height: illustrationSize,
                    child: Image.asset(
                      'assets/images/bakaloo-offline-state-illustration.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: EdgeInsets.only(bottom: 84.h),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Service unavailable',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h1.copyWith(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF151515),
                            letterSpacing: -0.2,
                          ),
                        ),
                        Gap(6.h),
                        TextButton(
                          onPressed: onRetry,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.orderViolet,
                            textStyle: AppTextStyles.buttonMedium.copyWith(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 6.h,
                            ),
                          ),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
