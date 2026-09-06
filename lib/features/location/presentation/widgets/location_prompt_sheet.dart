import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/utils/location_service_resolver.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/location/presentation/providers/location_prompt_provider.dart';
import 'package:bakaloo_flutter_app/features/location/presentation/widgets/location_permission_denied_dialog.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

/// Shows the location permission bottom sheet.
/// Call this from the home screen after the first frame.
///
/// [autoTrigger] — when true (permission already granted and service
/// already on, so detection is expected to just work), the sheet starts
/// detecting the moment it opens instead of waiting for an "Enable" tap.
/// The customer still sees the sheet itself and its spinner/status text —
/// this only removes the redundant extra tap, it doesn't hide the process.
///
/// [mandatory] — when true (the customer has no saved address at all —
/// they can't place an order without one), the sheet has no close button,
/// can't be swiped away or tapped outside, and the Android back button is
/// blocked: "Use my current location" or "Add address manually" are the
/// only ways out. When false (they already have an address and this is
/// just a "your location's off" courtesy nudge), it stays dismissible as
/// before — there's nothing to force here.
///
/// Returns the address that was just auto-detected and saved, if the
/// customer resolved this via "Use my current location" — reverse
/// geocoding only ever knows the street/area, never a house or building
/// number, so the caller (home_screen.dart) uses this to immediately chain
/// into the address-completion screen instead of leaving that half-filled.
/// Returns null for every other way out (already had an address, resolved
/// it via "Add address manually" — that screen already collects house/
/// building number itself — or detection failed).
Future<AddressEntity?> showLocationPromptSheet(
  BuildContext context, {
  bool autoTrigger = false,
  bool mandatory = false,
}) async {
  return showModalBottomSheet<AddressEntity>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    isDismissible: !mandatory,
    enableDrag: !mandatory,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (_) => _LocationPromptSheet(
      autoTrigger: autoTrigger,
      mandatory: mandatory,
    ),
  );
}

class _LocationPromptSheet extends ConsumerStatefulWidget {
  const _LocationPromptSheet({
    this.autoTrigger = false,
    this.mandatory = false,
  });

  final bool autoTrigger;
  final bool mandatory;

  @override
  ConsumerState<_LocationPromptSheet> createState() =>
      _LocationPromptSheetState();
}

class _LocationPromptSheetState extends ConsumerState<_LocationPromptSheet> {
  _SheetState _state = _SheetState.idle;
  String? _statusMessage;
  // Null while checking. Drives which heading copy to show — the sheet can
  // now appear even when location is already fully on (triggered instead
  // by the customer having no saved address yet), so "Your location is
  // off" would be flat wrong in that case.
  bool? _serviceEnabled;

  @override
  void initState() {
    super.initState();
    Geolocator.isLocationServiceEnabled().then((enabled) {
      if (mounted) setState(() => _serviceEnabled = enabled);
    });
    if (widget.autoTrigger) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onEnable();
      });
    }
  }

  Future<void> _onEnable() async {
    if (_state == _SheetState.loading) return;
    setState(() {
      _state = _SheetState.loading;
      _statusMessage = 'Detecting your location…';
    });

    await _detectAndHandleResult();
  }

  // Split out from _onEnable so the locationServiceDisabled case below can
  // retry detection immediately after the native "turn on location" dialog
  // resolves, without going back through _onEnable's loading-guard (which
  // would just no-op since _state is still _SheetState.loading at that
  // point).
  Future<void> _detectAndHandleResult() async {
    final result = await detectAndSaveCurrentLocation(ref);

    if (!mounted) return;

    switch (result) {
      case LocationAutoDetectResult.success:
        setState(() {
          _state = _SheetState.success;
          _statusMessage = 'Location saved as your default address!';
        });
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        if (!mounted) return;
        // Reverse geocoding only ever knows the street/area — never a house
        // or building number — so hand the freshly-created address back to
        // the caller (home_screen.dart) instead of just closing: it chains
        // straight into the completion screen so that never gets left
        // half-filled with no prompt to finish it.
        final addresses = ref.read(addressProvider).asData?.value ?? const [];
        final newAddress = addresses.isEmpty
            ? null
            : addresses.firstWhere(
                (a) => a.isDefault,
                orElse: () => addresses.first,
              );
        Navigator.of(context).pop(newAddress);

      case LocationAutoDetectResult.permissionDenied:
        setState(() {
          _state = _SheetState.idle;
          _statusMessage = 'Permission denied. You can enable it later.';
        });

      case LocationAutoDetectResult.permissionPermanentlyDenied:
        // Once permission is permanently denied, the OS will never show its
        // own system prompt again for this install — re-tapping "Enable"
        // here can only ever come back with this same result, which reads
        // as "the pop-up isn't coming anymore" even though that's the OS
        // working as designed. A status message alone was a dead end with
        // no way to actually recover, so this also offers the one path that
        // still works: the app's own Settings page — and, mirroring the
        // locationServiceDisabled case below, retries detection immediately
        // if the customer actually comes back from it instead of leaving
        // them to notice nothing happened and tap Enable a second time.
        // Reported: "he press that enable automatic... pop-up... that also
        // pop-up not coming."
        setState(() {
          _state = _SheetState.idle;
          _statusMessage =
              'Location permission is blocked. Enable it in Settings.';
        });
        final openedSettings =
            await LocationPermissionDeniedDialog.show(context);
        if (!mounted) return;
        if (!openedSettings) return;

        setState(() {
          _state = _SheetState.loading;
          _statusMessage = 'Turn on location, then come back here…';
        });
        await waitForAppResume();
        if (!mounted) return;

        setState(() => _statusMessage = 'Detecting your location…');
        await _detectAndHandleResult();

      case LocationAutoDetectResult.locationServiceDisabled:
        // Show the native "Turn on Location Accuracy" resolution dialog
        // in-app (Android, via requestEnableLocationService) instead of
        // bouncing the customer out to the OS Settings app and back —
        // matches the Zomato/Blinkit-style flow: tap Enable, the native
        // dialog appears right over this sheet, tap "Turn on", and
        // detection continues immediately without ever leaving the app.
        // Reported: "that direct redirect map turn on settings page... not
        // do... like Blinkit, Zomato... I need that way."
        //
        // On iOS specifically this can now sit here for a while — there's
        // no native in-app dialog on iOS, so requestEnableLocationService
        // opens Settings and then genuinely waits for the customer to find
        // Location Services and switch it on before returning, rather than
        // wrongly reporting failure the instant Settings finishes opening
        // (the bug this replaced). "Detecting…" would be misleading during
        // that wait, since nothing is being detected yet.
        setState(
          () => _statusMessage = 'Turn on location, then come back here…',
        );
        final enabled = await requestEnableLocationService();
        if (!mounted) return;

        if (enabled) {
          // Service is on now — retry detection right away instead of
          // making the customer tap Enable a second time.
          setState(() => _statusMessage = 'Detecting your location…');
          await _detectAndHandleResult();
          return;
        }

        setState(() {
          _state = _SheetState.idle;
          _statusMessage = 'Please turn on device location and try again.';
        });

      case LocationAutoDetectResult.geocodingFailed:
      case LocationAutoDetectResult.saveFailed:
      case LocationAutoDetectResult.unknown:
        setState(() {
          _state = _SheetState.idle;
          _statusMessage = 'Could not detect location. Try again later.';
        });

      case LocationAutoDetectResult.notServiceable:
        // No address gets saved for a non-serviceable location — the
        // backend hard-blocks it (ADDRESS_NOT_SERVICEABLE) — and
        // detectAndSaveCurrentLocation already recorded that the customer
        // was detected here via nonServiceableLocationProvider, for the
        // cart to surface later (CartBottomBar's "Your area is not
        // serviceable" state). Nothing to interrupt onboarding with here:
        // close the sheet exactly like a successful detection would,
        // straight into the app — the customer only ever learns their area
        // isn't served yet if and when they try to actually order.
        Navigator.of(context).pop();
    }
  }

  void _onSwipeDismiss(DragEndDetails details) {
    final canDismiss = !widget.mandatory;
    if (canDismiss && (details.primaryVelocity ?? 0) > 200) {
      Navigator.of(context).pop();
    }
  }

  void _onDismiss() {
    Navigator.of(context).pop();
  }

  Future<void> _onAddManually() async {
    final changed = await context.push<bool>(RouteNames.addAddress);
    if (changed == true && mounted) Navigator.of(context).pop();
  }

  void _onSeeAllAddresses() {
    Navigator.of(context).pop();
    context.push(RouteNames.addresses);
  }

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(addressProvider);
    final AddressEntity? savedAddress = addressesAsync.maybeWhen(
      data: (addresses) => addresses.isEmpty ? null : addresses.first,
      orElse: () => null,
    );

    final bool canDismiss = !widget.mandatory;

    final bool isOff = _serviceEnabled == false;

    return PopScope(
      // Blocks the Android back gesture/button too — isDismissible/enableDrag
      // passed to showModalBottomSheet only cover tap-outside and the
      // framework's own built-in swipe-down, so without this a "mandatory"
      // sheet would still have a dismiss path left open.
      canPop: canDismiss,
      child: GestureDetector(
        onVerticalDragEnd: _onSwipeDismiss,
        child: SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Logo + close button (close omitted entirely when mandatory —
                // there's no way out of this sheet except resolving it, so a
                // button that's just going to sit there disabled would only
                // confuse the customer about why it doesn't do anything).
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 14.h, 16.w, 0),
                  child: Row(
                    children: <Widget>[
                      Image.asset(
                        'assets/images/freshcuts-logo-wordmark.png',
                        height: 32.h,
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                      ),
                      const Spacer(),
                      if (canDismiss)
                        GestureDetector(
                          onTap: _onDismiss,
                          child: Container(
                            width: 28.w,
                            height: 28.w,
                            decoration: const BoxDecoration(
                              color: AppColors.bgSection,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Image.asset(
                  'assets/images/freshcuts-set-location-illustration.png',
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 28.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                            color: const Color(0xFF1A1A1A),
                          ),
                          children: isOff
                              ? <TextSpan>[
                                  const TextSpan(text: 'Your location is '),
                                  TextSpan(
                                    text: 'off',
                                    style: TextStyle(color: AppColors.brandRed),
                                  ),
                                ]
                              : <TextSpan>[
                                  const TextSpan(text: 'Set your '),
                                  TextSpan(
                                    text: 'delivery location',
                                    style: TextStyle(color: AppColors.brandRed),
                                  ),
                                ],
                        ),
                      ),
                      Gap(8.h),
                      Text(
                        isOff
                            ? 'Turn it on for faster, more accurate delivery.'
                            : 'Enable location to find products, check '
                                'delivery availability, and get the fastest '
                                'doorstep delivery near you.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      if (_statusMessage != null) ...<Widget>[
                        Gap(14.h),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 10.h,
                          ),
                          decoration: BoxDecoration(
                            color: _state == _SheetState.success
                                ? AppColors.brandRedSurface
                                : const Color(0xFFFFF3CD),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                _state == _SheetState.success
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.info_outline_rounded,
                                size: 16.sp,
                                color: _state == _SheetState.success
                                    ? AppColors.brandRed
                                    : const Color(0xFF856404),
                              ),
                              Gap(8.w),
                              Flexible(
                                child: Text(
                                  _statusMessage!,
                                  textAlign: TextAlign.left,
                                  style: TextStyle(
                                    fontFamily: 'DMSans',
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    color: _state == _SheetState.success
                                        ? AppColors.brandRedDark
                                        : const Color(0xFF856404),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Gap(22.h),
                      _PromptButton(
                        label: _state == _SheetState.loading
                            ? 'Detecting…'
                            : 'Enable Location',
                        icon: PhosphorIcons.mapPinFill,
                        filled: true,
                        loading: _state == _SheetState.loading,
                        onTap: _state == _SheetState.loading ? null : _onEnable,
                      ),
                      Gap(12.h),
                      _PromptButton(
                        label: savedAddress != null
                            ? 'View Saved Address'
                            : 'Enter Location Manually',
                        icon: savedAddress != null
                            ? PhosphorIcons.mapPinFill
                            : PhosphorIcons.pencilSimpleLineFill,
                        filled: false,
                        onTap: savedAddress != null
                            ? _onSeeAllAddresses
                            : _onAddManually,
                      ),
                      Gap(16.h),
                      Text(
                        'You can change your location anytime later.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
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

class _PromptButton extends StatelessWidget {
  const _PromptButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final PhosphorIconData icon;
  final bool filled;
  final bool loading;
  final VoidCallback? onTap;

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
              if (loading)
                SizedBox(
                  width: 18.sp,
                  height: 18.sp,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: filled ? Colors.white : AppColors.brandRed,
                  ),
                )
              else
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

enum _SheetState { idle, loading, success }
