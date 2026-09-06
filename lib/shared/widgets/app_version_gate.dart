import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bakaloo_flutter_app/core/network/app_version_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/shared/widgets/bakaloo_state_screen.dart';

/// App-wide force/soft update gate, alongside [AppAvailabilityGate] in
/// app.dart's builder. A force-update verdict renders a non-dismissible
/// full-screen blocker on top of [child] (mirrors AppAvailabilityGate's
/// Positioned.fill pattern); a soft-update verdict shows a dismissible
/// bottom sheet once per app session and never blocks anything underneath.
class AppVersionGate extends ConsumerStatefulWidget {
  const AppVersionGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppVersionGate> createState() => _AppVersionGateState();
}

class _AppVersionGateState extends ConsumerState<AppVersionGate> {
  bool _softPromptShown = false;

  @override
  Widget build(BuildContext context) {
    final resultAsync = ref.watch(appVersionCheckProvider);

    ref.listen<AsyncValue<AppVersionCheckResult>>(appVersionCheckProvider, (
      _,
      next,
    ) {
      final result = next.asData?.value;
      if (result == null || _softPromptShown) return;
      if (result.severity == AppUpdateSeverity.soft) {
        _softPromptShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showSoftUpdateSheet(result);
        });
      }
    });

    final result = resultAsync.asData?.value;
    final showForceBlocker = result?.canForceUpdate ?? false;

    return Stack(
      children: <Widget>[
        widget.child,
        if (showForceBlocker)
          Positioned.fill(
            child: _ForceUpdateScreen(result: result!),
          ),
      ],
    );
  }

  void _showSoftUpdateSheet(AppVersionCheckResult result) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => _SoftUpdateSheet(result: result),
    );
  }
}

Future<void> _openStore(String? storeUrl) async {
  if (storeUrl == null || storeUrl.trim().isEmpty) return;
  final uri = Uri.tryParse(storeUrl.trim());
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Full-screen, non-dismissible — the only way out is the update button.
/// [AppVersionCheckResult.canForceUpdate] already guarantees [storeUrl] is
/// non-empty before this is ever shown, so there's always a way forward.
class _ForceUpdateScreen extends StatelessWidget {
  const _ForceUpdateScreen({required this.result});

  final AppVersionCheckResult result;

  @override
  Widget build(BuildContext context) {
    final message = (result.updateMessage?.trim().isNotEmpty ?? false)
        ? result.updateMessage!.trim()
        : 'A new version of Bakaloo is available'
            '${result.latestVersionName != null ? ' (v${result.latestVersionName})' : ''}. '
            'Please update to continue.';

    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 96.w,
                  height: 96.w,
                  decoration: const BoxDecoration(
                    color: AppColors.orderVioletSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: PhosphorIcon(
                      PhosphorIcons.arrowsClockwiseBold,
                      size: 44.sp,
                      color: AppColors.orderViolet,
                    ),
                  ),
                ),
                Gap(24.h),
                Text(
                  'Update Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                Gap(10.h),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.sp,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                Gap(32.h),
                SizedBox(
                  width: double.infinity,
                  child: BakalooStateButton(
                    label: 'Update Now',
                    filled: true,
                    onTap: () => _openStore(result.storeUrl),
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

/// Dismissible "an update is available" nudge — shown once per app session,
/// never blocks anything. The customer can keep using the app either way.
class _SoftUpdateSheet extends StatelessWidget {
  const _SoftUpdateSheet({required this.result});

  final AppVersionCheckResult result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 20.h),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: const BoxDecoration(
                    color: AppColors.orderVioletSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    color: AppColors.orderViolet,
                    size: 24.sp,
                  ),
                ),
                Gap(14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'A new version is available',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      Gap(4.h),
                      Text(
                        (result.updateMessage?.trim().isNotEmpty ?? false)
                            ? result.updateMessage!.trim()
                            : 'Update Bakaloo${result.latestVersionName != null ? ' to v${result.latestVersionName}' : ''} for the latest features and fixes.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.sp,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Gap(20.h),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF555555),
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      minimumSize: Size(0, 48.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: const Text('Later'),
                  ),
                ),
                Gap(12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _openStore(result.storeUrl);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orderViolet,
                      foregroundColor: Colors.white,
                      minimumSize: Size(0, 48.h),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: const Text('Update Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
