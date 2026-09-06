import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/network/app_availability_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/routing/app_router.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/widgets/bakaloo_state_screen.dart';

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
            child: BakalooStateScreen(
              illustrationAsset:
                  'assets/images/bakaloo-offline-state-illustration.png',
              icon: PhosphorIcons.wifiSlashBold,
              title: "You're offline",
              subtitle:
                  'Please check your internet connection\nand try again.',
              primaryLabel: 'Retry',
              onPrimary: () =>
                  ref.read(appAvailabilityProvider.notifier).retry(),
              secondaryLabel: 'Browse saved items',
              onSecondary: () {
                ref.read(appAvailabilityProvider.notifier).browseOffline();
                // Navigate via the router instance (this gate lives above the
                // Router subtree, so `context.go` has no GoRouter ancestor).
                ref.read(appRouterProvider).go(RouteNames.wishlist);
              },
            ),
          )
        else if (status == AppAvailabilityStatus.serviceUnavailable)
          Positioned.fill(
            child: _ServiceUnavailableBlocker(
              onRetry: () =>
                  ref.read(appAvailabilityProvider.notifier).retry(),
            ),
          ),
      ],
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
