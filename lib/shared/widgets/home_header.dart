import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/providers/price_mode_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/features/notifications/presentation/providers/unread_count_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/widgets/b2b_segment_toggle.dart';

/// Premium white-lavender top header.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({
    required this.addressText,
    required this.onAddressTap,
    this.topBarTheme,
    this.searchZoneColor,
    this.deliveryEtaMinutes,
    this.topPaddingOverride,
    super.key,
  });

  final String addressText;
  final VoidCallback onAddressTap;
  final TopBarTheme? topBarTheme;

  /// Color used by the curved bottom strip so it matches the search zone
  /// background beneath it. Defaults to white when not provided.
  final Color? searchZoneColor;

  /// Admin-set delivery-time badge (e.g. 45 → "⚡ 45 mins delivery"), shown
  /// when the dashboard has configured one; nothing is shown otherwise.
  final int? deliveryEtaMinutes;

  /// When something is already occupying the status-bar area above this
  /// header (e.g. [OrderTrackingTopBanner]), that widget passes 0 here so
  /// the header doesn't also pad for it — avoiding a doubled gap. Null
  /// (the default) keeps the normal behavior of padding by the device's
  /// own top safe-area inset.
  final double? topPaddingOverride;

  static const Color _lavenderTop = Color(0xFFEDE4FB);
  static const Color _lavenderBottom = Color(0xFFF6F1FD);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topInset = topPaddingOverride ?? MediaQuery.paddingOf(context).top;

    // Use the dashboard-configured top bar color when available.
    // Fall back to the default lavender gradient only when no theme is provided.
    final bool topBarColorEnabled = topBarTheme?.colorEnabled ?? true;
    final Color? themeColor =
        topBarColorEnabled ? topBarTheme?.backgroundColor : null;
    // Dashboard's "Top bar text color" — was previously only ever applied to
    // the background above; the delivery-eta/address text and its icons
    // stayed hardcoded black regardless of this setting, so a dark top bar
    // background (e.g. admin-picked maroon/red) rendered unreadable black
    // text over it. Falls back to black to match the light default header.
    final Color topTextColor = topBarTheme?.textColor ?? Colors.black;

    final Decoration headerDecoration = !topBarColorEnabled
        // Admin explicitly disabled this row's color (pairs with a
        // Header Background image set behind it) — paint nothing so
        // that image shows through instead of falling back to the
        // lavender default, which would just be a different opaque color.
        ? const BoxDecoration(color: Colors.transparent)
        : themeColor != null
            ? BoxDecoration(color: themeColor)
            : const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[_lavenderTop, _lavenderBottom],
                ),
              );

    return Container(
      width: double.infinity,
      decoration: headerDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, topInset + 0.h, 16.w, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          // Only the dashboard-configured ETA is shown. There
                          // is no bundled fallback claim (this used to print a
                          // hard-coded "6 mins" when no ETA was configured).
                          if (deliveryEtaMinutes != null) ...<Widget>[
                            Text(
                              '⚡ $deliveryEtaMinutes mins delivery',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w700,
                                height: 1.05,
                                letterSpacing: -0.5,
                                color: topTextColor,
                              ),
                            ),
                            Gap(4.h),
                          ],
                          Semantics(
                            button: true,
                            label: 'Delivery address: $addressText',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onAddressTap,
                                borderRadius: BorderRadius.circular(8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.location_on_outlined,
                                      color: topTextColor,
                                      size: 17.sp,
                                    ),
                                    Gap(4.w),
                                    Flexible(
                                      child: Text(
                                        addressText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w500,
                                          color: topTextColor,
                                        ),
                                      ),
                                    ),
                                    Gap(2.w),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: topTextColor,
                                      size: 18.sp,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Gap(10.w),
                    const _HeaderActions(),
                  ],
                ),
                Gap(2.h),
              ],
            ),
          ),
          // Downward curved divider into the content below.
          // The color matches the search-zone background so the curve
          // blends seamlessly regardless of the active theme color.
          ClipPath(
            clipper: const _HeaderBottomCurveClipper(),
            child: Container(
              height: 10.h,
              color: searchZoneColor ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded top-left and top-right corners that divide the lavender header
/// from the white content area below.
class _HeaderBottomCurveClipper extends CustomClipper<Path> {
  const _HeaderBottomCurveClipper();

  @override
  Path getClip(Size size) {
    const double r = 16.0; // corner radius
    return Path()
      ..moveTo(0, size.height)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(size.width - r, 0)
      ..quadraticBezierTo(size.width, 0, size.width, r)
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// B2B/B2C browsing toggle plus a directly accessible notification centre.
/// Profile remains available in the persistent navigation, which avoids
/// cramming three action buttons into the narrow phone header.
class _HeaderActions extends ConsumerWidget {
  const _HeaderActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCountProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _PriceModeToggle(),
        Gap(10.w),
        _NotificationsButton(
          size: 42.w,
          unreadCount: unreadCount,
          onTap: () => context.go(RouteNames.notifications),
        ),
      ],
    );
  }
}

/// Self-service B2B/B2C browsing toggle. See [PriceModeNotifier] — this
/// only tracks and persists the customer's chosen mode; it doesn't change
/// any prices yet (that needs a separate, carefully-tested pass through
/// product listing, cart and checkout).
class _PriceModeToggle extends ConsumerWidget {
  const _PriceModeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(priceModeProvider);
    final isWholesale = mode == PriceMode.wholesale;

    return SizedBox(
      width: 96.w,
      child: B2BSegmentToggle(
        value: isWholesale ? BusinessMode.b2b : BusinessMode.b2c,
        onChanged: (next) {
          final notifier = ref.read(priceModeProvider.notifier);
          final wantsWholesale = next == BusinessMode.b2b;
          if (wantsWholesale != isWholesale) notifier.toggle();
        },
      ),
    );
  }
}

class _NotificationsButton extends StatelessWidget {
  const _NotificationsButton({
    required this.size,
    required this.unreadCount,
    required this.onTap,
  });

  final double size;
  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: unreadCount > 0
          ? 'Notifications, $unreadCount unread'
          : 'Notifications',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Color(0x242A1A47),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                ClipOval(
                  child: ColoredBox(
                    color: Colors.white,
                    child: Center(
                      child: PhosphorIcon(
                        PhosphorIcons.bell,
                        size: 24.sp,
                        color: const Color(0xFF2A1A47),
                      ),
                    ),
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: -2.h,
                    right: -2.w,
                    child: Container(
                      constraints:
                          BoxConstraints(minWidth: 16.w, minHeight: 16.h),
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD9202A),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Inter',
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
