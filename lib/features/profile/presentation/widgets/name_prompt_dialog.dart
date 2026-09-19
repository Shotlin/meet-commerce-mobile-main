import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/features/profile/presentation/providers/profile_provider.dart';

/// Mandatory "what's your name?" popup shown on Home when the logged-in
/// user has no name on file yet (OTP-only signup never asks for one).
/// Entering and saving a name is the only way out — no tap-outside, no
/// back button, no "maybe later" — so every customer's address/orders
/// carry a real name from the start instead of a generic placeholder.
Future<void> showNamePromptDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => const _NamePromptDialog(),
  );
}

class _NamePromptDialog extends ConsumerStatefulWidget {
  const _NamePromptDialog();

  @override
  ConsumerState<_NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends ConsumerState<_NamePromptDialog> {
  // Matches the app's actual brand accent (auth screens, bottom nav) — not
  // exposed via AppColors, which only has the green used for cart/delivery
  // CTAs, so it's defined locally here same as those other call sites do.
  static const Color _brandColor = AppColors.brandRed;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final FocusNode _firstNameFocusNode = FocusNode();
  final FocusNode _lastNameFocusNode = FocusNode();
  bool _isSaving = false;
  String? _errorText;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _firstNameFocusNode.dispose();
    _lastNameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    if (firstName.isEmpty || lastName.isEmpty) {
      setState(() => _errorText = 'Please enter your first and last name');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final name = '$firstName $lastName';
    final result = await ref.read(profileProvider.notifier).updateProfile(
          name: name,
        );

    if (!mounted) return;

    if (result.isSuccess) {
      Navigator.of(context).pop();
      AppToast.show(context, '👋 Thanks, $firstName!', type: ToastType.success);
    } else {
      setState(() {
        _isSaving = false;
        _errorText = result.failure?.message ?? 'Could not save your name.';
      });
    }
  }

  InputDecoration _nameFieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      counterText: '',
      filled: true,
      fillColor: const Color(0xFFF0F4F8),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16.w,
        vertical: 14.h,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: const BorderSide(
          color: _brandColor,
          width: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // barrierDismissible: false above already blocks tap-outside; this
      // blocks the Android back gesture/button, the one dismiss path that
      // would otherwise still be open.
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        insetPadding: EdgeInsets.symmetric(horizontal: 28.w),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    color: _brandColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: PhosphorIcon(
                      PhosphorIcons.userCircleFill,
                      size: 30.sp,
                      color: _brandColor,
                    ),
                  ),
                ),
              ),
              Gap(16.h),
              Text(
                "What's your name?",
                textAlign: TextAlign.center,
                style: AppTextStyles.h2,
              ),
              Gap(6.h),
              Text(
                "We'll use this to personalize your orders and greet you\naround the app.",
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Gap(20.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _firstNameController,
                      focusNode: _firstNameFocusNode,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      maxLength: 30,
                      onSubmitted: (_) => _lastNameFocusNode.requestFocus(),
                      onChanged: (_) {
                        if (_errorText != null)
                          setState(() => _errorText = null);
                      },
                      style: AppTextStyles.bodyLarge,
                      decoration: _nameFieldDecoration('First name'),
                    ),
                  ),
                  Gap(12.w),
                  Expanded(
                    child: TextField(
                      controller: _lastNameController,
                      focusNode: _lastNameFocusNode,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      maxLength: 30,
                      onSubmitted: (_) => _save(),
                      onChanged: (_) {
                        if (_errorText != null)
                          setState(() => _errorText = null);
                      },
                      style: AppTextStyles.bodyLarge,
                      decoration: _nameFieldDecoration('Last name'),
                    ),
                  ),
                ],
              ),
              if (_errorText != null) ...<Widget>[
                Gap(6.h),
                Text(
                  _errorText!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              Gap(18.h),
              SizedBox(
                height: 50.h,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _brandColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMd,
                      ),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Save',
                          style: AppTextStyles.buttonLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
