import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/screens/coupons_screen.dart';
import 'package:bakaloo_flutter_app/features/profile/presentation/providers/profile_provider.dart';
import 'package:bakaloo_flutter_app/features/profile/presentation/widgets/delete_account_dialog.dart';
import 'package:bakaloo_flutter_app/features/profile/presentation/widgets/logout_sheet.dart';
import 'package:bakaloo_flutter_app/features/tutorials/presentation/screens/tutorial_list_screen.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/entities/wallet_entity.dart';
import 'package:bakaloo_flutter_app/routing/app_router.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/widgets/contact_support_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const Color _brandColor = AppColors.brandRed;

  final LocalAuthentication _localAuth = LocalAuthentication();
  final InAppReview _inAppReview = InAppReview.instance;

  String _appVersion = '1.0.0';
  String _appBuildNumber = '1';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(profileProvider.notifier).fetchProfile());
      ref.invalidate(userStatsProvider);
      // Wallet balance can change server-side (admin credit, refund,
      // cashback) without this app ever knowing — refetch every time the
      // profile screen (which shows the wallet balance) opens.
      unawaited(ref.read(walletProvider.notifier).refreshWallet());
    });
    unawaited(_loadAppVersion());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(profileProvider, (previous, next) {
      if (!mounted || !next.hasError || next.isLoading) {
        return;
      }
      final previousError = previous?.error;
      if (previousError != next.error) {
        final message = next.error.toString().replaceFirst('Bad state: ', '');
        AppToast.show(context, message);
      }
    });

    final profileAsync = ref.watch(profileProvider);
    final currentUser = ref.watch(currentUserProvider);
    // FIX: Use walletProvider (WalletNotifier, keepAlive) instead of
    // walletBalanceProvider (auto-dispose) so the balance persists across
    // rebuilds and always shows the correct fetched value.
    final walletAsync = ref.watch(walletProvider);
    final statsAsync = ref.watch(userStatsProvider);
    final addressesAsync = ref.watch(addressProvider);
    final profileData = profileAsync.asData?.value;
    final user = profileData?.user ?? currentUser;

    if (user == null && profileAsync.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brandRed),
        ),
      );
    }

    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Unable to load your profile.',
                style: AppTextStyles.bodyMedium,
              ),
              Gap(10.h),
              FilledButton(
                onPressed: () {
                  unawaited(ref.read(profileProvider.notifier).fetchProfile());
                },
                child: Text('Retry', style: AppTextStyles.buttonMedium),
              ),
            ],
          ),
        ),
      );
    }

    final ordersPlaced = statsAsync.asData?.value.totalOrders;
    final addressCount = addressesAsync.asData?.value.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            // ── Top bar ──
            SizedBox(
              height: 48.h,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(
                        Icons.arrow_back,
                        size: 22.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    'Account',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // ── "Hi {name}" + contact + Edit ──
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 14.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Hi ${user.name?.trim().isNotEmpty == true ? user.name : 'there'}',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 21.sp,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Gap(4.h),
                                Text(
                                  <String>[
                                    user.phone,
                                    if ((user.email ?? '').trim().isNotEmpty)
                                      user.email!.trim(),
                                  ].join(' | '),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12.5.sp,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _openEditProfile,
                            child: Text(
                              'Edit',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w700,
                                color: _brandColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Rewards / promo banner ──
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: _RewardsBanner(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CouponsScreen(),
                          ),
                        ),
                      ),
                    ),

                    Gap(20.h),

                    // ── Account section (no header, matches reference) ──
                    _AccountSection(
                      rows: <Widget>[
                        _AccountRow(
                          icon: PhosphorIcons.packageLight,
                          title: 'Orders',
                          subtitle: 'Orders Placed: ${ordersPlaced ?? 0}',
                          onTap: () => context.push(RouteNames.orders),
                        ),
                        const _AccountRowDivider(),
                        _AccountRow(
                          icon: PhosphorIcons.walletLight,
                          title: 'Wallet',
                          subtitle: 'Balance: ${_walletLabel(walletAsync)}',
                          onTap: () =>
                              context.push('${RouteNames.profile}/wallet'),
                        ),
                        const _AccountRowDivider(),
                        _AccountRow(
                          icon: PhosphorIcons.mapPinLight,
                          title: 'Addresses',
                          subtitle: addressCount == null
                              ? 'Loading…'
                              : addressCount == 0
                                  ? 'No saved addresses'
                                  : '$addressCount saved address${addressCount == 1 ? '' : 'es'}',
                          onTap: () =>
                              context.push('${RouteNames.profile}/addresses'),
                        ),
                        const _AccountRowDivider(),
                        _AccountRow(
                          icon: PhosphorIcons.heartLight,
                          title: 'Wishlist',
                          onTap: () => context.push(RouteNames.wishlist),
                        ),
                        const _AccountRowDivider(),
                        _AccountRow(
                          icon: PhosphorIcons.ticketLight,
                          title: 'Coupons',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const CouponsScreen(),
                            ),
                          ),
                        ),
                        const _AccountRowDivider(),
                        _AccountRow(
                          icon: PhosphorIcons.bellRingingLight,
                          title: 'Notification preferences',
                          onTap: () => context.push(
                            '${RouteNames.profile}/notifications/preferences',
                          ),
                        ),
                      ],
                    ),

                    Gap(8.h),
                    _SectionGap(),
                    Gap(8.h),

                    _AccountSection(
                      header: 'FreshCuts Zone',
                      rows: <Widget>[
                        _AccountRow(
                          icon: PhosphorIcons.forkKnifeLight,
                          title: 'Recipes',
                          onTap: () => _openLegalPage('/recipes'),
                        ),
                        const _AccountRowDivider(),
                        _AccountRow(
                          icon: PhosphorIcons.rocketLight,
                          title: 'Blogs',
                          onTap: () => _openLegalPage('/blogs'),
                        ),
                        const _AccountRowDivider(),
                        _AccountRow(
                          icon: PhosphorIcons.fileTextLight,
                          title: 'Terms & conditions',
                          onTap: () => _openLegalPage('/terms'),
                        ),
                        const _AccountRowDivider(),
                        _AccountRow(
                          icon: PhosphorIcons.questionLight,
                          title: 'FAQs',
                          onTap: () => _openLegalPage('/faqs'),
                        ),
                        const _AccountRowDivider(),
                        _AccountRow(
                          icon: PhosphorIcons.shieldCheckLight,
                          title: 'Privacy policy',
                          onTap: () => _openLegalPage('/privacy'),
                        ),
                        const _AccountRowDivider(),
                        _AccountRow(
                          icon: PhosphorIcons.chatCircleTextLight,
                          title: 'Contact Us',
                          onTap: _showSupportSheet,
                        ),
                        const _AccountRowDivider(),
                        _AccountRow(
                          icon: PhosphorIcons.bellSimpleRingingLight,
                          title: 'Cancellation & Reschedule Policy',
                          onTap: () => _openLegalPage('/cancellation-policy'),
                        ),
                        const _AccountRowDivider(),
                        _AccountRow(
                          icon: PhosphorIcons.videoCameraLight,
                          title: 'Tutorial',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const TutorialListScreen(),
                            ),
                          ),
                        ),
                        const _AccountRowDivider(),
                        _AccountRow(
                          icon: PhosphorIcons.shareFatLight,
                          title: 'Share the app',
                          onTap: () {
                            Share.share(
                              'Order fresh meat & seafood on FreshCuts: ${ApiConstants.webBaseUrl}',
                            );
                          },
                        ),
                        const _AccountRowDivider(),
                        _AccountRow(
                          icon: PhosphorIcons.starLight,
                          title: 'Rate us',
                          onTap: _rateApp,
                        ),
                        const _AccountRowDivider(),
                        _AccountRow(
                          icon: PhosphorIcons.infoLight,
                          title: 'About us',
                          onTap: _showAbout,
                        ),
                        const _AccountRowDivider(),
                        _AccountRow(
                          icon: PhosphorIcons.trashLight,
                          title: 'Delete Account',
                          isDanger: true,
                          onTap: _deleteAccount,
                        ),
                      ],
                    ),

                    Gap(8.h),
                    _SectionGap(),
                    Gap(8.h),

                    _AccountSection(
                      rows: <Widget>[
                        _AccountRow(
                          icon: PhosphorIcons.signOutLight,
                          title: 'Logout',
                          onTap: () => LogoutSheet.show(context),
                        ),
                      ],
                    ),

                    Gap(20.h),

                    Center(
                      child: Text(
                        'App Version: $_appVersion ($_appBuildNumber)',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.sp,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLegalPage(String path) async {
    // NOT externalApplication: this app is a verified Android App Links
    // handler for bakaloo.in (for shared product links), so the OS hands
    // a bakaloo.in/* URL straight back to this same app instead of a
    // browser — go_router then throws "no routes for location" since these
    // are web-only pages. inAppWebView renders the URL directly without
    // going through OS link resolution at all (same pattern already used
    // for Privacy/Terms below).
    await launchUrl(
      Uri.parse('${ApiConstants.webBaseUrl}$path'),
      mode: LaunchMode.inAppWebView,
    );
  }

  Future<void> _openEditProfile() async {
    final changed = await context.push<bool>('${RouteNames.profile}/edit');
    if (!mounted || changed != true) {
      return;
    }
    await ref.read(profileProvider.notifier).fetchProfile();
    ref.invalidate(userStatsProvider);
  }

  Future<void> _deleteAccount() async {
    final confirmed = await DeleteAccountDialog.show(context);
    if (!mounted || confirmed != true) {
      return;
    }

    final authenticated = await _authenticateForDelete();
    if (!mounted || !authenticated) {
      return;
    }

    final result = await ref.read(profileProvider.notifier).deleteAccount();
    if (!mounted) {
      return;
    }

    if (!result.isSuccess && result.failure != null) {
      AppToast.show(context, result.failure!.message);
      return;
    }
    context.go(RouteNames.phone);
  }

  Future<bool> _authenticateForDelete() async {
    try {
      final canUseBiometric = await _localAuth.canCheckBiometrics;
      final deviceSupported = await _localAuth.isDeviceSupported();
      if (!canUseBiometric || !deviceSupported) {
        return true;
      }
      return await _localAuth.authenticate(
        localizedReason: 'Confirm your identity to delete account',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _showSupportSheet() {
    return showContactSupportSheet(context, title: 'Need help?');
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'FreshCuts',
      applicationVersion: _appVersion,
      applicationLegalese: '© ${DateTime.now().year} FreshCuts',
    );
  }

  Future<void> _rateApp() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        return;
      }
    } catch (_) {
      // Fall through and show feedback.
    }
    if (!mounted) {
      return;
    }
    AppToast.show(
      context,
      '⚠️ Rating is not available right now.',
      type: ToastType.warning,
    );
  }

  // FIX: Now receives AsyncValue<WalletEntity> from walletProvider instead of
  // AsyncValue<double> from the auto-dispose walletBalanceProvider.
  //
  // Reads `.value` (not `.when`'s `loading:`/`data:` branches) so a reload —
  // e.g. the invalidate this screen's own initState triggers, or one fired
  // after a wallet-funded order — keeps showing the last known balance
  // instead of flashing back to '...' (`.when`'s `loading:` branch fires on
  // every AsyncLoading state regardless of whether it's carrying a previous
  // value forward).
  String _walletLabel(AsyncValue<dynamic> walletAsync) {
    final wallet = walletAsync.value;
    // walletProvider returns WalletEntity with .balance field.
    if (wallet is WalletEntity) {
      return wallet.balance.toInrCurrency;
    }
    // Fallback: if somehow a double slips through.
    if (wallet is double) {
      return wallet.toInrCurrency;
    }
    return walletAsync.hasError ? '--' : '...';
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() {
      _appVersion = info.version;
      _appBuildNumber = info.buildNumber;
    });
  }
}

/// Dark gradient rewards/promo card — this app has no loyalty-tier program
/// of its own, so it links to Coupons (the closest real equivalent) rather
/// than a fictional membership screen.
class _RewardsBanner extends StatelessWidget {
  const _RewardsBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.r),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[
                  Color(0xFF3D0A10),
                  AppColors.brandRedDark,
                ],
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Save more on every order!',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14.5.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Gap(3.h),
                      Text(
                        'Get exclusive discounts & free delivery',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Gap(10.w),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Explore',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFFD466),
                      ),
                    ),
                    Gap(3.w),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 15.sp,
                      color: const Color(0xFFFFD466),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionGap extends StatelessWidget {
  const _SectionGap();

  @override
  Widget build(BuildContext context) {
    return Container(height: 8.h, color: const Color(0xFFF5F5F5));
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.rows, this.header});

  final List<Widget> rows;
  final String? header;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (header != null)
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 8.h),
            child: Text(
              header!,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ...rows,
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.isDanger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? AppColors.errorRed : AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            children: <Widget>[
              PhosphorIcon(icon, size: 20.sp, color: color),
              Gap(14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      Gap(2.h),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PhosphorIcon(
                PhosphorIcons.caretRight,
                size: 15.sp,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountRowDivider extends StatelessWidget {
  const _AccountRowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Divider(height: 1.h, thickness: 1, color: AppColors.divider),
    );
  }
}
