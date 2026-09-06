import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/branding/branding_provider.dart';
import 'package:bakaloo_flutter_app/core/providers/store_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/features/notifications/presentation/providers/unread_count_provider.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';

const String _defaultLogoAsset = 'assets/icon/brand_logo.png';

/// Premium white-lavender top header.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({
    required this.addressText,
    required this.onAddressTap,
    required this.onNotificationTap,
    this.onWalletTap,
    this.topBarTheme,
    this.searchZoneColor,
    this.deliveryEtaMinutes,
    this.topPaddingOverride,
    super.key,
  });

  final String addressText;
  final VoidCallback onAddressTap;
  final VoidCallback onNotificationTap;
  final VoidCallback? onWalletTap;
  final TopBarTheme? topBarTheme;
  /// Color used by the curved bottom strip so it matches the search zone
  /// background beneath it. Defaults to white when not provided.
  final Color? searchZoneColor;
  /// Admin-set delivery-time badge (e.g. 45 → "⚡ 45 mins delivery"), shown
  /// only on the main Zepto store front in place of its static "6 mins"
  /// tagline. Other store fronts keep their own static taglines.
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
    final store = ref.watch(selectedStoreProvider);
    final logoImageUrl = ref.watch(
      brandingProvider.select((config) => config.logoImageUrl),
    );

    // Use the dashboard-configured top bar color when available.
    // Fall back to the default lavender gradient only when no theme is provided.
    final Color? themeColor = topBarTheme?.backgroundColor;
    // Dashboard's "Top bar text color" — was previously only ever applied to
    // the background above; the delivery-eta/address text and its icons
    // stayed hardcoded black regardless of this setting, so a dark top bar
    // background (e.g. admin-picked maroon/red) rendered unreadable black
    // text over it. Falls back to black to match the light default header.
    final Color topTextColor = topBarTheme?.textColor ?? Colors.black;

    final Decoration headerDecoration = themeColor != null
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
                // Centered brand logo on top.
                SizedBox(
                  height: 40.h,
                  child: logoImageUrl == null
                      ? Image.asset(
                          _defaultLogoAsset,
                          height: 40.h,
                          cacheHeight: 160,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                        )
                      : AppImage(
                          imageUrl: logoImageUrl,
                          memCacheWidth: 320,
                          memCacheHeight: 160,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          placeholder: Image.asset(
                            _defaultLogoAsset,
                            height: 40.h,
                            fit: BoxFit.contain,
                          ),
                          errorWidget: Image.asset(
                            _defaultLogoAsset,
                            height: 40.h,
                            fit: BoxFit.contain,
                          ),
                        ),
                ),
                // Pull the bottom row up so it sits tight under the logo.
                Transform.translate(
                  offset: Offset(0, -10.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            (deliveryEtaMinutes != null && store.id == 'zepto')
                                ? '⚡ $deliveryEtaMinutes mins delivery'
                                : store.subtitle,
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
                          GestureDetector(
                            onTap: onAddressTap,
                            behavior: HitTestBehavior.opaque,
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
                        ],
                      ),
                    ),
                    Gap(10.w),
                    _HeaderActions(
                      onWalletTap: onWalletTap,
                      onNotificationTap: onNotificationTap,
                    ),
                  ],
                  ),
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

/// Wallet + profile circular actions kept on a shared baseline so both
/// circles align, while the wallet balance pill overhangs below.
class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.onWalletTap,
    required this.onNotificationTap,
  });

  final VoidCallback? onWalletTap;
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    final double circle = 46.w;
    final double gap = 12.w;

    return SizedBox(
      width: circle * 2 + gap,
      height: circle + 14.h,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // Both circles aligned on the same top baseline.
          Positioned(
            top: 0,
            left: 0,
            child: Row(
              children: <Widget>[
                _CircleIconButton(
                  asset: 'assets/icon/wallet_icon.png',
                  size: circle,
                  iconSize: 38.w,
                  onTap: onWalletTap,
                ),
                Gap(gap),
                _CircleNotificationButton(
                  size: circle,
                  onTap: onNotificationTap,
                ),
              ],
            ),
          ),
          // Balance pill, centered under the wallet (left) circle.
          Positioned(
            bottom: 0,
            left: -10.w,
            width: circle + 20.w,
            child: const Center(child: _WalletPill()),
          ),
        ],
      ),
    );
  }
}

class _WalletPill extends ConsumerWidget {
  const _WalletPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FIX: Use walletProvider (WalletNotifier, keepAlive) so the pill shows
    // the same balance already loaded by the wallet screen/profile — no
    // separate fetch, no independent error state.
    // `.value` (not `.asData?.value`) so the pill keeps showing the last
    // known balance while a refetch is in flight (e.g. right after a
    // wallet-funded order invalidates this provider) instead of vanishing —
    // `.asData` is strictly null during AsyncLoading even when the loading
    // state is carrying forward a previous value.
    final balance = ref.watch(walletProvider).value?.balance;
    if (balance == null || balance <= 0) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: const Color(0xFFD02428),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFD02428).withValues(alpha: 0.32),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '\u20b9${_formatBalance(balance)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.0,
        ),
      ),
    );
  }

  String _formatBalance(double value) {
    final intVal = value.round();
    final str = intVal.toString();
    if (str.length <= 3) return str;
    final lastThree = str.substring(str.length - 3);
    var rest = str.substring(0, str.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    return '${groups.join(',')},$lastThree';
  }
}

class _CircleNotificationButton extends ConsumerWidget {
  const _CircleNotificationButton({
    required this.size,
    required this.onTap,
  });

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This bell is the app's only always-visible notification affordance
    // (shown on the home screen, not just inside the Notifications list
    // itself) — it previously never reflected unread state at all, on
    // either platform, so a customer had no way to tell a notification had
    // arrived without opening the tab proactively.
    final unread = ref.watch(unreadCountProvider);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
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
              child: ClipOval(
                child: ColoredBox(
                  color: Colors.white,
                  child: Center(
                    child: PhosphorIcon(
                      PhosphorIcons.bell,
                      size: 22.sp,
                      color: const Color(0xFF2A1A47),
                    ),
                  ),
                ),
              ),
            ),
            if (unread > 0)
              Positioned(
                top: -2.h,
                right: -2.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                  constraints: BoxConstraints(minWidth: 18.w, minHeight: 18.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE23744),
                    borderRadius: BorderRadius.circular(999.r),
                    border: Border.all(color: Colors.white, width: 1.5.w),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.asset,
    required this.size,
    required this.iconSize,
    required this.onTap,
  });

  final String asset;
  final double size;
  final double iconSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
        child: ClipOval(
          child: ColoredBox(
            color: Colors.white,
            child: Center(
              child: Image.asset(
                asset,
                width: iconSize,
                height: iconSize,
                cacheWidth: (iconSize * 6).round(),
                cacheHeight: (iconSize * 6).round(),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
