import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/location/presentation/providers/guest_storefront_provider.dart';
import 'package:bakaloo_flutter_app/features/location/presentation/widgets/location_prompt_sheet.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

/// First-run storefront gate. The preview never watches home providers, so a
/// new guest cannot trigger catalogue APIs before their store is resolved.
class GuestLocationGate extends ConsumerStatefulWidget {
  const GuestLocationGate({required this.state, super.key});

  final GuestStorefrontState state;

  @override
  ConsumerState<GuestLocationGate> createState() => _GuestLocationGateState();
}

class _GuestLocationGateState extends ConsumerState<GuestLocationGate> {
  // Guards against acting twice, whether that's presenting the sheet or
  // navigating straight to the not-serviceable screen — see _handleState.
  bool _handled = false;
  late final ProviderSubscription<GuestStorefrontState>
      _guestStorefrontSubscription;

  @override
  void initState() {
    super.initState();
    // A valid signed guest storefront is read locally. Wait for that restore
    // to finish instead of treating its short loading state as a new guest
    // and asking for location again on every cold reopen.
    _guestStorefrontSubscription = ref.listenManual<GuestStorefrontState>(
      guestStorefrontProvider,
      (_, next) {
        if (next.isReady || next.status == GuestStorefrontStatus.loading) {
          return;
        }
        _scheduleLocationPrompt();
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _guestStorefrontSubscription.close();
    super.dispose();
  }

  void _scheduleLocationPrompt() {
    if (_handled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = ref.read(guestStorefrontProvider);
      if (mounted &&
          !_handled &&
          !current.isReady &&
          current.status != GuestStorefrontStatus.loading) {
        _handleState(current);
      }
    });
    // A provider update after the first rendered frame does not necessarily
    // schedule another frame on its own. Request one so the callback above
    // cannot leave the customer on a permanent blurred skeleton.
    WidgetsBinding.instance.scheduleFrame();
  }

  void _handleState(GuestStorefrontState current) {
    // `unavailable` here means we already resolved this exact location once
    // (this session, or restored from a persisted "checked, not
    // serviceable" record on cold start — see guest_storefront_provider.dart)
    // and it genuinely isn't served. Re-showing the mandatory "Enable
    // Location" sheet would only ever land back on this same answer, so it
    // was the real cause of the sheet reappearing on every reopen for a
    // customer whose area isn't served yet — nothing about their situation
    // was ever going to change by asking again. Go straight to the
    // not-serviceable screen instead, exactly like the sheet's own
    // guestStorefront+unavailable branch already does after a fresh
    // detection (location_prompt_sheet.dart#_onEnable).
    if (current.status == GuestStorefrontStatus.unavailable) {
      _handled = true;
      final attemptedLocation = <String>[
        if (current.city?.trim().isNotEmpty ?? false) current.city!.trim(),
        if (current.pincode?.trim().isNotEmpty ?? false)
          current.pincode!.trim(),
      ].join(', ');
      GoRouter.of(context).go(
        '${RouteNames.locationUnavailable}?guest=1',
        extra: attemptedLocation.isEmpty ? null : attemptedLocation,
      );
      return;
    }
    _presentSheet();
  }

  void _presentSheet() {
    if (!mounted || _handled) return;
    _handled = true;
    unawaited(
      showLocationPromptSheet(
        context,
        mandatory: true,
        guestStorefront: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const StorefrontAccessLoadingSkeleton();
  }
}

/// The blurred storefront skeleton, with no behaviour of its own — no
/// provider listeners, no location prompts. [GuestLocationGate] renders this
/// while its own listener decides whether a guest actually needs the
/// location-enable sheet; other callers (see AppShell in app_bottom_nav.dart)
/// use it directly as a neutral "still resolving" placeholder for cases
/// where [GuestLocationGate]'s guest-only side effects must not run.
class StorefrontAccessLoadingSkeleton extends StatelessWidget {
  const StorefrontAccessLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const _StorefrontSkeletonPreview(),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: const ColoredBox(color: Color(0x55000000)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StorefrontSkeletonPreview extends StatelessWidget {
  const _StorefrontSkeletonPreview();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 220.h),
        children: <Widget>[
          const _SkeletonBar(widthFactor: .46, height: 24),
          SizedBox(height: 12.h),
          const _SkeletonBar(widthFactor: 1, height: 44),
          SizedBox(height: 20.h),
          const _SkeletonBlock(height: 150),
          SizedBox(height: 24.h),
          const _SkeletonBar(widthFactor: .38, height: 20),
          SizedBox(height: 12.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: .68,
            ),
            itemBuilder: (_, __) => const _SkeletonBlock(height: 100),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.widthFactor, required this.height});
  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: Alignment.centerLeft,
        child: _SkeletonBlock(height: height),
      );
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height.h,
        decoration: BoxDecoration(
          color: AppColors.bgSkeleton,
          borderRadius: BorderRadius.circular(12.r),
        ),
      );
}
