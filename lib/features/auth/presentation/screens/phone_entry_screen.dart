import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/utils/validators.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  static const String _heroAsset = 'assets/images/freshcuts-login-hero.jpg';
  static const Color _brandColor = AppColors.brandRed;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  bool _hasInteracted = false;

  late final TapGestureRecognizer _termsTapRecognizer =
      TapGestureRecognizer()..onTap = () => _openLegalPage('/terms');
  late final TapGestureRecognizer _privacyTapRecognizer =
      TapGestureRecognizer()..onTap = () => _openLegalPage('/privacy');

  @override
  void dispose() {
    _phoneController.dispose();
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

      if (next case AuthOtpSent(:final phone)) {
        context.push('${RouteNames.otp}?phone=$phone');
        return;
      }

      if (next case AuthAuthenticated()) {
        unawaited(
          ref.read(authGateControllerProvider).consumeAndResume(context),
        );
        return;
      }

      if (next case AuthError(:final message)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthLoading;
    final phoneError = _hasInteracted
        ? Validators.validatePhone(_phoneController.text.trim())
        : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: <Widget>[
            // ── Hero illustration (full-screen, edge-to-edge) ──
            // Real FreshCuts brand artwork — logo, headline, and subtitle
            // are all baked into the image itself, so no text/icon overlay
            // is layered on top of it here.
            Positioned.fill(
              child: Image.asset(
                _heroAsset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            // ── Skip button (top-right) ──
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8.h,
              right: 16.w,
              child: GestureDetector(
                onTap: () => context.go(RouteNames.home),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Skip',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: _brandColor,
                        ),
                      ),
                      Gap(2.w),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: _brandColor,
                        size: 18.sp,
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 240.ms),

            // ── Bottom welcome sheet ──
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28.r),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, -8),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                            24.w,
                            26.h,
                            24.w,
                            18.h + MediaQuery.paddingOf(context).bottom,
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                // ── Welcome heading ──
                                Text.rich(
                                  TextSpan(
                                    text: 'Welcome to ',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 28.sp,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      height: 1.2,
                                    ),
                                    children: <InlineSpan>[
                                      const TextSpan(
                                        text: 'FreshCuts',
                                        style: TextStyle(
                                          color: _brandColor,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                    .animate()
                                    .fadeIn(duration: 280.ms)
                                    .slideY(begin: 0.1, end: 0),

                                Gap(6.h),

                                // ── Subtitle ──
                                Text(
                                  'Fresh chicken, mutton & fish at your doorstep.',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ).animate().fadeIn(delay: 60.ms, duration: 280.ms),

                                Gap(22.h),

                                // ── Phone input box ──
                                _PhoneInputBox(
                                  controller: _phoneController,
                                  brandColor: _brandColor,
                                  hasError: phoneError != null,
                                  onChanged: (_) {
                                    if (!_hasInteracted) {
                                      setState(() => _hasInteracted = true);
                                      return;
                                    }
                                    setState(() {});
                                  },
                                  onSubmitted: (_) => _submitPhone(),
                                )
                                    .animate()
                                    .fadeIn(delay: 120.ms, duration: 280.ms)
                                    .slideY(begin: 0.08, end: 0),

                                // ── Inline validation error ──
                                if (phoneError != null) ...<Widget>[
                                  Gap(8.h),
                                  Padding(
                                    padding: EdgeInsets.only(left: 4.w),
                                    child: Text(
                                      phoneError,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.errorRed,
                                      ),
                                    ),
                                  ),
                                ],

                                Gap(16.h),

                                // ── Continue button ──
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : _submitPhone,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _brandColor,
                                      disabledBackgroundColor:
                                          _brandColor.withValues(alpha: 0.5),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      minimumSize: Size.fromHeight(56.h),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                      ),
                                    ),
                                    child: isLoading
                                        ? SizedBox(
                                            width: 22.w,
                                            height: 22.w,
                                            child:
                                                const CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            'Continue',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 16.sp,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                )
                                    .animate()
                                    .fadeIn(delay: 180.ms, duration: 280.ms)
                                    .slideY(begin: 0.08, end: 0),

                                Gap(14.h),

                                // ── Terms footer ──
                                Center(
                                  child: Text.rich(
                                    TextSpan(
                                      text: 'By continuing, you agree to our ',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12.sp,
                                        color: AppColors.textTertiary,
                                        height: 1.5,
                                      ),
                                      children: <InlineSpan>[
                                        TextSpan(
                                          text: 'Terms & Conditions',
                                          style: const TextStyle(
                                            color: _brandColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          recognizer: _termsTapRecognizer,
                                        ),
                                        const TextSpan(text: ' and '),
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
                                ).animate().fadeIn(delay: 240.ms, duration: 240.ms),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  void _submitPhone() {
    setState(() {
      _hasInteracted = true;
    });

    final normalizedPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    ref.read(authNotifierProvider.notifier).sendOtp(normalizedPhone);
  }
}

/// Phone input box matching the reference: a light rounded field with the
/// "+91 ▾" prefix, a divider, and the number input. Limited to 10 digits — an
/// 11th keystroke is rejected before it ever appears.
class _PhoneInputBox extends StatelessWidget {
  const _PhoneInputBox({
    required this.controller,
    required this.brandColor,
    required this.hasError,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final Color brandColor;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: hasError
              ? AppColors.errorRed
              : const Color(0xFFE4DFF2),
          width: 1.4,
        ),
      ),
      child: Row(
        children: <Widget>[
          Text(
            '+91',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Gap(4.w),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18.sp,
            color: AppColors.textSecondary,
          ),
          Gap(12.w),
          Container(
            width: 1.4,
            height: 30.h,
            color: const Color(0xFFE4DFF2),
          ),
          Gap(12.w),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
              cursorColor: brandColor,
              // Digits only + hard cap at 10 — the 11th digit never appears.
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: Validators.validatePhone,
              autovalidateMode: AutovalidateMode.disabled,
              onChanged: onChanged,
              onFieldSubmitted: onSubmitted,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                hintText: 'Enter your number',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textTertiary,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 16.h),
                errorStyle: const TextStyle(height: 0, fontSize: 0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
