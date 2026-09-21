import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/features/profile/presentation/providers/profile_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  DateTime? _birthday;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Deliberately keyed off profileProvider alone (the live GET /users/me),
    // not currentUserProvider — that's the cached JWT identity and the
    // access token never carries a name claim. ProfileScreen forces a fresh
    // fetch on every visit, so this screen can easily first build while that
    // fetch is still in flight; falling back to the JWT user here would lock
    // _initialized in with permanently empty fields once the real profile
    // data arrives, since the block below only ever runs once.
    final profileData = ref.watch(profileProvider).asData?.value;

    if (!_initialized && profileData != null) {
      _nameController.text = profileData.user.name ?? '';
      _emailController.text = profileData.user.email ?? '';
      _birthday = profileData.birthday;
      _initialized = true;
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            'assets/images/freshcuts-edit-profile-background.png',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 40.w,
                            height: 40.w,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_back,
                              size: 20.sp,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Image.asset(
                            'assets/images/freshcuts-logo-wordmark.png',
                            height: 46.h,
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(width: 40.w),
                      ],
                    ),
                    Gap(20.h),
                    Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Gap(4.h),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 26.sp,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          color: const Color(0xFF1A1A1A),
                        ),
                        children: <TextSpan>[
                          const TextSpan(text: 'Your Details,\n'),
                          TextSpan(
                            text: 'A Fresher You',
                            style: TextStyle(color: AppColors.brandRed),
                          ),
                        ],
                      ),
                    ),
                    Gap(8.h),
                    SizedBox(
                      width: 220.w,
                      child: Text(
                        'Keep your information up to date for a better '
                        'experience.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                    Gap(18.h),
                    Container(
                      padding: EdgeInsets.all(18.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: const Color(0x14000000),
                            blurRadius: 24.r,
                            offset: Offset(0, 8.h),
                          ),
                        ],
                      ),
                      child: Column(
                        children: <Widget>[
                          _ProfileField(
                            icon: PhosphorIcons.userFill,
                            label: 'Full Name',
                            controller: _nameController,
                            hint: 'Enter your name',
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.length < 2) {
                                return 'Name must be at least 2 characters';
                              }
                              return null;
                            },
                          ),
                          Gap(16.h),
                          _ProfileField(
                            icon: PhosphorIcons.envelopeSimpleFill,
                            label: 'Email Address',
                            controller: _emailController,
                            hint: 'Enter your email',
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) return null;
                              final valid = RegExp(
                                r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                              ).hasMatch(text);
                              return valid
                                  ? null
                                  : 'Enter a valid email address';
                            },
                          ),
                          Gap(16.h),
                          _ProfileField(
                            icon: PhosphorIcons.calendarDotsFill,
                            label: 'Date of Birth',
                            hint: 'Select birthday',
                            readOnlyText: _birthday == null
                                ? null
                                : DateFormat('dd MMM yyyy').format(_birthday!),
                            onTap: _pickBirthday,
                          ),
                        ],
                      ),
                    ),
                    Gap(18.h),
                    Material(
                      color: AppColors.brandRed,
                      borderRadius: BorderRadius.circular(28.r),
                      child: InkWell(
                        onTap: _isSaving ? null : _save,
                        borderRadius: BorderRadius.circular(28.r),
                        child: Container(
                          height: 54.h,
                          alignment: Alignment.center,
                          child: _isSaving
                              ? SizedBox(
                                  width: 22.sp,
                                  height: 22.sp,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 15.5.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Gap(8.w),
                                    Icon(
                                      Icons.arrow_forward,
                                      size: 18.sp,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    Gap(14.h),
                    Text(
                      'Fresher Everyday',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.sp,
                        color: AppColors.brandRed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1950),
      lastDate: now,
    );
    if (selected == null) {
      return;
    }
    setState(() => _birthday = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    final result = await ref.read(profileProvider.notifier).updateProfile(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          birthday: _birthday,
        );

    if (!mounted) {
      return;
    }

    if (!result.isSuccess && result.failure != null) {
      // Only re-enable Save on failure, so the customer can fix the issue
      // and retry — on success this screen is leaving for good (see below),
      // so there's no case where it needs to become interactive again.
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.failure!.message)),
      );
      return;
    }

    // context.pop(true) used to be used here, relying on this screen having
    // been reached via a plain push. That pop was reported as unreliable —
    // sometimes leaving this exact form on screen after a successful save,
    // and repeated Save taps while confused about that could corrupt the
    // route stack into a blank page. go(home) sidesteps all of that: it's
    // the same mechanism push-notification deep links already use to land
    // reliably on a specific screen from anywhere in the app (see
    // fcm_service.dart) — it replaces the entire navigation stack in one
    // atomic step instead of depending on however this screen happened to
    // be reached, so there's no pop-stack state left to get out of sync.
    ref
      ..invalidate(profileProvider)
      ..invalidate(userStatsProvider);
    context.go(RouteNames.home);
    AppToast.show(
      context,
      'Profile updated successfully',
      type: ToastType.success,
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.icon,
    required this.label,
    required this.hint,
    this.controller,
    this.keyboardType,
    this.validator,
    this.readOnlyText,
    this.onTap,
  });

  final PhosphorIconData icon;
  final String label;
  final String hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final String? readOnlyText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 40.w,
          height: 40.w,
          margin: EdgeInsets.only(top: 20.h),
          decoration: BoxDecoration(
            color: AppColors.brandRedSurface,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Center(
            child: PhosphorIcon(
              icon,
              size: 18.sp,
              color: AppColors.brandRed,
            ),
          ),
        ),
        Gap(12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              Gap(6.h),
              if (onTap != null)
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12.r),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            readOnlyText ?? hint,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13.sp,
                              color: readOnlyText == null
                                  ? AppColors.textTertiary
                                  : const Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 16.sp,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                )
              else
                TextFormField(
                  controller: controller,
                  keyboardType: keyboardType,
                  validator: validator,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 13.sp),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.sp,
                      color: AppColors.textTertiary,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 12.h,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(
                          color: AppColors.brandRed, width: 1.2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
