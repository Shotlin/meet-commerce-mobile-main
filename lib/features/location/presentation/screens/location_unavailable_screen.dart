import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

/// Shown when FreshCuts does not yet serve the customer's selected location
/// (no shop matches the pincode/delivery radius). Reached from two real
/// triggers: the address form after the backend rejects a save with
/// ADDRESS_NOT_SERVICEABLE (add_edit_address_screen.dart), and the
/// "use my current location" onboarding prompt when auto-detection lands
/// outside every shop's service area (home_screen.dart, after
/// showLocationPromptSheet resolves with nonServiceableLocationProvider set).
class LocationUnavailableScreen extends StatelessWidget {
  const LocationUnavailableScreen({
    this.attemptedLocationLabel,
    this.showSignIn = false,
    this.onChangeLocation,
    this.onNotify,
    super.key,
  });

  /// The city/pincode the customer actually tried, when the caller has it
  /// (the address form knows exactly what was rejected). Falls back to a
  /// generic label when null — e.g. reached from the auto-detect path,
  /// which never collects a human-readable place name.
  final String? attemptedLocationLabel;

  /// Signed-out customers reach this screen before the app can read their
  /// saved delivery address. Let them sign in directly rather than trapping
  /// them behind a GPS-only location gate.
  final bool showSignIn;

  /// Optional overrides — primarily for previewing/testing. When omitted the
  /// screen wires sensible default navigation.
  final VoidCallback? onChangeLocation;
  final VoidCallback? onNotify;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFE),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(top: 12.h, bottom: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Image.asset(
                      'assets/images/freshcuts-logo-wordmark.png',
                      height: 42.h,
                      fit: BoxFit.contain,
                    ),
                    const Spacer(),
                    _LocationPill(
                      label: attemptedLocationLabel ?? 'Selected location',
                    ),
                  ],
                ),
              ),
              Gap(8.h),
              // Cropped to a fixed height (not the source PNG's full
              // implied height at this width) — the artwork has a lot of
              // empty space below the character, and letting that render
              // at full size pushed the heading/buttons much further down
              // than the layout needs.
              SizedBox(
                width: double.infinity,
                height: 300.h,
                child: Image.asset(
                  'assets/images/freshcuts-location-unavailable-illustration.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
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
                          const TextSpan(text: "We're currently "),
                          TextSpan(
                            text: 'not',
                            style: TextStyle(color: AppColors.brandRed),
                          ),
                          const TextSpan(text: ' serving this area'),
                        ],
                      ),
                    ),
                    Gap(10.h),
                    Text(
                      "Looks like your selected location is outside our "
                      "delivery zone. We're expanding quickly — stay tuned!",
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
                    _LocationUnavailableButton(
                      label: 'Notify Me When Available',
                      icon: PhosphorIcons.bellBold,
                      filled: true,
                      onTap: onNotify ??
                          () {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Thanks! We'll notify you when FreshCuts "
                                    'reaches your area.',
                                  ),
                                ),
                              );
                          },
                    ),
                    Gap(12.h),
                    _LocationUnavailableButton(
                      label: 'Try a Different Location',
                      icon: PhosphorIcons.mapPinBold,
                      filled: false,
                      onTap: onChangeLocation ??
                          () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              // Guest users reach this screen before login,
                              // so returning to Home reopens the location
                              // picker instead of sending them to the
                              // authenticated addresses route.
                              context.go(RouteNames.home);
                            }
                          },
                    ),
                    if (showSignIn) ...<Widget>[
                      Gap(10.h),
                      TextButton(
                        onPressed: () => context.go(RouteNames.phone),
                        child: Text(
                          'Already have an account? Sign in',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandRed,
                          ),
                        ),
                      ),
                    ],
                    Gap(20.h),
                    _ExpansionBanner(),
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

class _LocationPill extends StatelessWidget {
  const _LocationPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: 160.w),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.location_on,
            size: 14.sp,
            color: AppColors.brandRed,
          ),
          Gap(4.w),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ),
          Gap(2.w),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16.sp,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _LocationUnavailableButton extends StatelessWidget {
  const _LocationUnavailableButton({
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
    return Material(
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
    );
  }
}

/// Decorative — there's no real "expansion updates" page to link to yet, so
/// this stays a plain informational strip rather than a fake tappable link.
class _ExpansionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.brandRedSurface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40.w,
            height: 40.w,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: PhosphorIcon(
                PhosphorIcons.storefrontBold,
                size: 20.sp,
                color: AppColors.brandRed,
              ),
            ),
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  "We're expanding to more areas",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                Gap(2.h),
                Text(
                  'Bringing fresh meats & seafood to more neighbourhoods soon!',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
