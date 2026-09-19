import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:pinput/pinput.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/security/screenshot_prevention.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/utils/validators.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({
    required this.phone,
    super.key,
  });

  final String phone;

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen>
    with SingleTickerProviderStateMixin {
  static const Color _brandColor = AppColors.brandRed;
  static const Color _headingColor = Color(0xFF1B1414);
  static const Color _boxBorder = Color(0xFFE9DEDE);
  static const String _bannerAsset =
      'assets/images/bakaloo-otp-background-illustration.png';
  static const String _logoAsset = 'assets/icon/brand_logo.png';

  final TextEditingController _otpController = TextEditingController();
  late final AnimationController _shakeController;
  late final TapGestureRecognizer _termsTapRecognizer = TapGestureRecognizer()
    ..onTap = () => _openLegalPage('/terms');
  late final TapGestureRecognizer _privacyTapRecognizer = TapGestureRecognizer()
    ..onTap = () => _openLegalPage('/privacy');

  Timer? _timer;
  int _secondsRemaining = 60;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(ScreenshotPrevention.enable());
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _startCountdown();
  }

  @override
  void dispose() {
    unawaited(ScreenshotPrevention.disable());
    _timer?.cancel();
    _shakeController.dispose();
    _otpController.dispose();
    _termsTapRecognizer.dispose();
    _privacyTapRecognizer.dispose();
    super.dispose();
  }

  Future<void> _openLegalPage(String path) async {
    final uri = Uri.parse('${ApiConstants.webBaseUrl}$path');
    // NOT externalApplication: this app is a verified Android App Links
    // handler for bakaloo.in (for shared product links), so the OS hands
    // a bakaloo.in/* URL straight back to this same app instead of a
    // browser — go_router then throws "no routes for location" since
    // /privacy and /terms are web-only pages. inAppWebView renders the
    // URL directly without going through OS link resolution at all.
    await launchUrl(uri, mode: LaunchMode.inAppWebView);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authNotifierProvider, (
      AuthState? previous,
      AuthState next,
    ) {
      final route = ModalRoute.of(context);
      if (!mounted || !(route?.isCurrent ?? false)) {
        return;
      }

      if (next case AuthAuthenticated()) {
        unawaited(
          ref.read(authGateControllerProvider).consumeAndResume(context),
        );
        return;
      }

      if (next case AuthError(:final message)) {
        unawaited(_handleOtpError(message));
        return;
      }

      if (next case AuthOtpSent()) {
        _startCountdown();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('OTP sent successfully.')),
          );
      }
    });

    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthLoading;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final pinWidth = ((screenWidth - 88.w) / 6).clamp(44.0, 56.0);

    final defaultPinTheme = PinTheme(
      width: pinWidth,
      height: 56.h,
      textStyle: TextStyle(
        fontFamily: 'Poppins',
        color: _headingColor,
        fontSize: 21.sp,
        fontWeight: FontWeight.w700,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _boxBorder, width: 1.4),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      color: Colors.white,
      border: Border.all(color: _brandColor, width: 1.8),
    );

    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      color: Colors.white,
      border: Border.all(color: AppColors.errorRed, width: 1.8),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(bottom: 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // ── Top bar: back + brand ──
                Padding(
                  padding: EdgeInsets.fromLTRB(8.w, 6.h, 20.w, 4.h),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: _headingColor,
                          size: 20.sp,
                        ),
                      ),
                      Gap(2.w),
                      Image.asset(
                        _logoAsset,
                        height: 30.h,
                        cacheHeight: 120,
                        fit: BoxFit.contain,
                      ),
                      Gap(8.w),
                      Text(
                        'Bakaloo',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 21.sp,
                          fontWeight: FontWeight.w800,
                          color: _headingColor,
                        ),
                      ),
                    ],
                  ),
                ),

                Gap(6.h),

                // ── Hero banner card ──
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20.r),
                    // Pure image — the headline, subtitle, feature icons and
                    // tagline are already baked into this banner artwork, so
                    // no app-rendered text/icons are drawn on top of it here
                    // (that would just duplicate what the image already
                    // shows). Same treatment as the category-page banners.
                    child: Image.asset(
                      _bannerAsset,
                      width: double.infinity,
                      height: 196.h,
                      fit: BoxFit.cover,
                      // This asset still has its own logo/tagline baked into
                      // its top portion (from the splash screen) — bottom
                      // alignment keeps the crop on the food photography and
                      // out of that text band until the real banner file
                      // (the one just sent in chat) can be added as its own
                      // asset — I couldn't save that paste to disk.
                      alignment: Alignment.bottomCenter,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 280.ms)
                    .slideY(begin: -0.03, end: 0),

                Gap(24.h),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Verify your number',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w800,
                          color: _headingColor,
                          height: 1.15,
                        ),
                      ),
                      Gap(6.h),
                      Text.rich(
                        TextSpan(
                          text: "We've sent a 6-digit OTP to ",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                          children: <InlineSpan>[
                            TextSpan(
                              text: _maskedPhone,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _headingColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Gap(22.h),

                      // ── OTP Pinput ──
                      AnimatedBuilder(
                        animation: _shakeController,
                        builder: (BuildContext context, Widget? child) {
                          final offset = math.sin(
                                _shakeController.value * math.pi * 6,
                              ) *
                              10;
                          return Transform.translate(
                            offset: Offset(offset, 0),
                            child: child,
                          );
                        },
                        child: Pinput(
                          controller: _otpController,
                          length: 6,
                          autofocus: false,
                          keyboardType: TextInputType.number,
                          defaultPinTheme: defaultPinTheme,
                          focusedPinTheme: focusedPinTheme,
                          submittedPinTheme: defaultPinTheme,
                          errorPinTheme: errorPinTheme,
                          forceErrorState: _hasError,
                          errorText: _errorMessage,
                          cursor: Container(
                            width: 2,
                            height: 26.h,
                            color: _brandColor,
                          ),
                          errorTextStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.errorRed,
                          ),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          onChanged: (String value) {
                            if (_hasError || _errorMessage != null) {
                              setState(() {
                                _hasError = false;
                                _errorMessage = null;
                              });
                            }
                          },
                          onCompleted: _submitOtp,
                        ),
                      ),

                      Gap(16.h),

                      // ── Resend row ──
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            "Didn't receive the code? ",
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          GestureDetector(
                            onTap: isLoading || _secondsRemaining > 0
                                ? null
                                : _resend,
                            child: Text(
                              'Resend OTP',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w700,
                                color: _secondsRemaining > 0
                                    ? _brandColor.withValues(alpha: 0.45)
                                    : _brandColor,
                              ),
                            ),
                          ),
                          if (_secondsRemaining > 0)
                            Text(
                              ' in $_formattedCountdown',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),

                      Gap(22.h),

                      // ── Verify & Continue ──
                      SizedBox(
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                AppColors.brandRedDark,
                                AppColors.brandRed,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(100.r),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: _brandColor.withValues(alpha: 0.32),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () => _submitOtp(_otpController.text),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              minimumSize: Size.fromHeight(56.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100.r),
                              ),
                            ),
                            child: isLoading
                                ? SizedBox(
                                    width: 22.w,
                                    height: 22.w,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                        'Verify & Continue',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Gap(8.w),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 18.sp,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),

                      Gap(12.h),

                      // ── Change number ──
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _headingColor,
                            side: BorderSide(color: _headingColor, width: 1.4),
                            minimumSize: Size.fromHeight(54.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100.r),
                            ),
                          ),
                          child: Text(
                            'Change number',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: _headingColor,
                            ),
                          ),
                        ),
                      ),

                      Gap(22.h),

                      // ── Trust badges ──
                      Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 16.h,
                          horizontal: 6.w,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBEEEE),
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: _TrustBadge(
                                icon: PhosphorIcons.shieldCheckBold,
                                title: 'Secure login',
                                subtitle: 'Your data is safe',
                              ),
                            ),
                            Expanded(
                              child: _TrustBadge(
                                icon: PhosphorIcons.truckBold,
                                title: 'Fast checkout',
                                subtitle: 'Save time',
                              ),
                            ),
                            Expanded(
                              child: _TrustBadge(
                                icon: PhosphorIcons.leafBold,
                                title: 'Fresh delivery\nin minutes',
                                subtitle: 'Good food, closer',
                              ),
                            ),
                          ],
                        ),
                      ),

                      Gap(18.h),

                      // ── Terms footer ──
                      Center(
                        child: Text.rich(
                          TextSpan(
                            text: 'By continuing, you agree to our ',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5.sp,
                              color: AppColors.textTertiary,
                              height: 1.5,
                            ),
                            children: <InlineSpan>[
                              TextSpan(
                                text: 'Terms',
                                style: const TextStyle(
                                  color: _brandColor,
                                  fontWeight: FontWeight.w700,
                                ),
                                recognizer: _termsTapRecognizer,
                              ),
                              const TextSpan(text: ' & '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: const TextStyle(
                                  color: _brandColor,
                                  fontWeight: FontWeight.w700,
                                ),
                                recognizer: _privacyTapRecognizer,
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                          textAlign: TextAlign.center,
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

  String get _maskedPhone {
    final raw = widget.phone.trim();
    if (raw.length <= 4) return '+91 $raw';
    final start = raw.substring(0, 2);
    final end = raw.substring(raw.length - 2);
    final masked = 'X' * (raw.length - 4);
    return '+91 $start$masked$end';
  }

  String get _formattedCountdown {
    final seconds = _secondsRemaining.toString().padLeft(2, '0');
    return '00:$seconds';
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = 60;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
        });
        return;
      }
      setState(() {
        _secondsRemaining -= 1;
      });
    });
  }

  void _resend() {
    setState(() {
      _hasError = false;
      _errorMessage = null;
    });
    ref.read(authNotifierProvider.notifier).sendOtp(widget.phone);
  }

  Future<void> _handleOtpError(String message) async {
    setState(() {
      _hasError = true;
      _errorMessage = message;
    });
    await _shakeController.forward(from: 0);
  }

  void _submitOtp(String value) {
    // Pinput can invoke onCompleted more than once for a single paste (the
    // paste delivers the 6 digits as more than one text-change event, and
    // each one that lands on a full value re-fires onCompleted). Without
    // this guard that fires two concurrent verifyOtp() calls for the same
    // code: whichever HTTP response resolves last wins the final auth
    // state, so a request that actually succeeded can be clobbered by a
    // second, redundant request failing (the OTP/session having already
    // been consumed by the first) — showing the user an error on a code
    // that was genuinely correct, forcing them to paste again.
    if (ref.read(authNotifierProvider) is AuthLoading) {
      return;
    }

    final error = Validators.validateOtp(value);
    if (error != null) {
      unawaited(_handleOtpError(error));
      return;
    }

    ref.read(authNotifierProvider.notifier).verifyOtp(
          phone: widget.phone,
          otp: value,
        );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 42.w,
          height: 42.w,
          decoration: const BoxDecoration(
            color: Color(0xFFF6D9D9),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 19.sp, color: AppColors.brandRed),
        ),
        Gap(8.h),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1B1414),
            height: 1.2,
          ),
        ),
        Gap(2.h),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 9.5.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.textTertiary,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
