import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/payment_offer_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_enhancement_providers.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/coupon_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/coupon_provider.dart';

// ─── Color tokens local to this screen ───────────────────────────────────────
const _kBg = Color(0xFFF4F6F8);
const _kCardBg = Colors.white;
const _kGreen = Color(0xFF0C831F);
const _kGreenLight = Color(0xFFE8F5E9);
const _kGreenMid = Color(0xFFCCEDD3);
const _kGold = Color(0xFFF0A000);
const _kGoldLight = Color(0xFFFFF4DD);
const _kGoldDark = Color(0xFF8A5A00);
const _kLocked = Color(0xFFF3F5F8);
const _kLockedFg = Color(0xFF9AA3B0);
const _kProgressBg = Color(0xFFE8EDF5);
const _kProviderBlue = Color(0xFF0B2559);
const _kProviderBluePill = Color(0xFFEFF3FF);
const _kProviderBluePillFg = Color(0xFF173E8F);
const _kBorder = Color(0xFFE8ECF0);
const _kDivider = Color(0xFFEEEEEE);
const _kInfoBg = Color(0xFFEDF7F0);
const _kInfoBorder = Color(0xFFB8DFC4);

class CouponsScreen extends ConsumerStatefulWidget {
  const CouponsScreen({super.key});

  @override
  ConsumerState<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends ConsumerState<CouponsScreen> {
  final Set<String> _expandedCoupons = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
        ..invalidate(availableCouponsProvider)
        ..invalidate(paymentOffersProvider);
    });
  }

  Future<void> _refreshData() async {
    ref
      ..invalidate(availableCouponsProvider)
      ..invalidate(paymentOffersProvider);
    try {
      await Future.wait<dynamic>(<Future<dynamic>>[
        ref.read(availableCouponsProvider.future),
        ref.read(paymentOffersProvider.future),
      ]);
    } catch (_) {}
  }

  Future<void> _applyCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return;

    final success =
        await ref.read(checkoutProvider.notifier).applyCoupon(normalized);
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    final error = ref.read(checkoutProvider).errorMessage;
    if (error == null || !context.mounted) return;

    ref.read(checkoutProvider.notifier).clearError();

    // The backend now names the exact category/products a scoped coupon
    // requires in this one message shape ("This coupon only ...") — that's
    // our signal to also show what's currently in the cart, so the
    // customer can see at a glance what to swap out. Every other coupon
    // failure (expired, min order, usage limit, account-targeting) still
    // gets the same nicer sheet, just without the cart preview.
    final isScopeMismatch = error.contains('coupon only');
    final cartItems = isScopeMismatch
        ? (ref.read(cartProvider).asData?.value.items ??
            const <CartItemEntity>[])
        : const <CartItemEntity>[];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _kCardBg,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (_) => _CouponIssueSheet(
        title: isScopeMismatch
            ? 'Coupon not applicable to your cart'
            : "Couldn't apply coupon",
        message: error,
        cartItems: cartItems,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final couponsAsync = ref.watch(availableCouponsProvider);
    final offersAsync = ref.watch(paymentOffersProvider);
    final checkoutState = ref.watch(checkoutProvider);
    final subtotal = ref.read(checkoutProvider.notifier).subtotal;

    final coupons = couponsAsync.asData?.value ?? const <CouponEntity>[];
    final offers = offersAsync.asData?.value ?? const <PaymentOfferEntity>[];

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        color: _kGreen,
        onRefresh: _refreshData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 36.h),
          children: <Widget>[
            // Applied coupon banner
            if (checkoutState.appliedCoupon != null) ...<Widget>[
              _AppliedBanner(
                coupon: checkoutState.appliedCoupon!,
                onRemove: () =>
                    ref.read(checkoutProvider.notifier).removeCoupon(),
              ),
              Gap(20.h),
            ],

            // ── Smart Coupons ─────────────────────────────────────────
            _PremiumSectionHeader(
              eyebrow: 'SMART COUPONS',
              eyebrowColor: _kGreen,
              eyebrowIcon: PhosphorIcons.tagFill,
              title: 'Best codes for this order',
              subtitle:
                  'These offers are ready to apply instantly on your current basket.',
            ),
            Gap(14.h),

            if (couponsAsync.isLoading && coupons.isEmpty) ...<Widget>[
              const _SkeletonCouponCard(),
              Gap(12.h),
              const _SkeletonCouponCard(),
            ] else if (couponsAsync.hasError && coupons.isEmpty)
              _ErrorCard(
                icon: PhosphorIcons.warningCircle,
                message: 'Unable to load coupons right now',
                onRetry: () => ref.invalidate(availableCouponsProvider),
              )
            else if (coupons.isEmpty)
              _EmptyCard(
                icon: PhosphorIcons.tag,
                title: 'No live coupons right now',
                subtitle:
                    'Try a code manually or use one of the payment offers below.',
              )
            else
              ...coupons.map((coupon) {
                final isApplied =
                    checkoutState.appliedCoupon?.code == coupon.code;
                final isEligible = subtotal >= coupon.minOrderAmount;
                final isExpanded = _expandedCoupons.contains(coupon.code);
                return Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: _PremiumCouponCard(
                    coupon: coupon,
                    subtotal: subtotal,
                    isApplied: isApplied,
                    isEligible: isEligible,
                    isExpanded: isExpanded,
                    onApply: isApplied ? null : () => _applyCode(coupon.code),
                    onToggleTerms: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedCoupons.remove(coupon.code);
                        } else {
                          _expandedCoupons.add(coupon.code);
                        }
                      });
                    },
                  ),
                );
              }),

            Gap(12.h),

            // ── Bank & UPI Offers ──────────────────────────────────────
            _PremiumSectionHeader(
              eyebrow: 'BANK & UPI OFFERS',
              eyebrowColor: _kGold,
              eyebrowIcon: PhosphorIcons.creditCardFill,
              title: 'Payment perks you can unlock',
              subtitle:
                  'These work on online payment and update based on your cart total.',
            ),
            Gap(14.h),

            if (offersAsync.isLoading && offers.isEmpty) ...<Widget>[
              const _SkeletonBankCard(),
              Gap(12.h),
              const _SkeletonBankCard(),
            ] else if (offersAsync.hasError && offers.isEmpty)
              _ErrorCard(
                icon: PhosphorIcons.creditCard,
                message: 'Unable to load payment offers',
                onRetry: () => ref.invalidate(paymentOffersProvider),
              )
            else if (offers.isEmpty)
              _EmptyCard(
                icon: PhosphorIcons.bank,
                title: 'No payment offers right now',
                subtitle:
                    'Once live offers are available, they will appear here automatically.',
              )
            else
              ...offers.map(
                (offer) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: _PremiumPaymentOfferCard(offer: offer),
                ),
              ),

            Gap(12.h),

            // ── How savings are applied ────────────────────────────────
            const _SavingsInfoCard(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kCardBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: Icon(
          PhosphorIcons.arrowLeftBold,
          size: 22.sp,
          color: AppColors.textPrimary,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Coupons & Offers',
            style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            'Curated savings for this cart',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11.5.sp,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        Container(
          margin: EdgeInsets.only(right: 14.w),
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: _kGreenLight,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            PhosphorIcons.giftFill,
            size: 20.sp,
            color: _kGreen,
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _kBorder),
      ),
    );
  }
}

// ─── Coupon Issue Sheet ────────────────────────────────────────────────────────
//
// Replaces the old plain red SnackBar shown whenever applying a coupon
// fails. A category/product-scoped coupon that doesn't match anything in
// the cart used to just say "specific products or categories aren't in
// your cart" with no way to act on it — this shows the actual message
// (which now names the required category/products) alongside the current
// cart contents, so the customer can see exactly what to swap out.

class _CouponIssueSheet extends StatelessWidget {
  const _CouponIssueSheet({
    required this.title,
    required this.message,
    required this.cartItems,
  });

  final String title;
  final String message;
  final List<CartItemEntity> cartItems;

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
                    color: _kGoldLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    PhosphorIcons.tagFill,
                    color: _kGoldDark,
                    size: 22.sp,
                  ),
                ),
                Gap(14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: AppTextStyles.h3.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16.5.sp,
                        ),
                      ),
                      Gap(5.h),
                      Text(
                        message,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (cartItems.isNotEmpty) ...<Widget>[
              Gap(18.h),
              Text(
                'CURRENTLY IN YOUR CART',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  fontSize: 10.5.sp,
                ),
              ),
              Gap(10.h),
              _CartItemsPreview(items: cartItems),
              Gap(8.h),
              Text(
                'Remove these and add matching items to your cart to use this coupon.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11.5.sp,
                  height: 1.4,
                ),
              ),
            ],
            Gap(20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  minimumSize: Size(0, 48.h),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small card listing the cart lines blocking a scoped coupon — image, name
/// and quantity for each, capped so the sheet never grows unreasonably tall
/// on a large cart.
class _CartItemsPreview extends StatelessWidget {
  const _CartItemsPreview({required this.items});

  final List<CartItemEntity> items;

  static const int _maxShown = 4;

  @override
  Widget build(BuildContext context) {
    final shown = items.take(_maxShown).toList(growable: false);
    final remaining = items.length - shown.length;

    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: <Widget>[
          for (var i = 0; i < shown.length; i++) ...<Widget>[
            if (i > 0)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Divider(height: 1, color: _kDivider),
              ),
            _CartItemRow(item: shown[i]),
          ],
          if (remaining > 0) ...<Widget>[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Divider(height: 1, color: _kDivider),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '+$remaining more item${remaining == 1 ? '' : 's'} in cart',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.sp,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  const _CartItemRow({required this.item});

  final CartItemEntity item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _CartItemThumb(url: item.thumbnailUrl, size: 40.w),
        Gap(10.w),
        Expanded(
          child: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelLarge.copyWith(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Gap(8.w),
        Text(
          '×${item.quantity}',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CartItemThumb extends StatelessWidget {
  const _CartItemThumb({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: SizedBox(
        width: size,
        height: size,
        child: (url != null && url!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                memCacheWidth: 96,
                memCacheHeight: 96,
                fadeInDuration: const Duration(milliseconds: 150),
                errorWidget: (context, url, error) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFFF0F2F5),
      alignment: Alignment.center,
      child: Icon(
        Icons.shopping_basket_outlined,
        size: size * 0.45,
        color: const Color(0xFFC5CBD3),
      ),
    );
  }
}

// ─── Applied Banner ────────────────────────────────────────────────────────────

class _AppliedBanner extends StatelessWidget {
  const _AppliedBanner({required this.coupon, required this.onRemove});
  final CouponEntity coupon;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: _kInfoBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: _kInfoBorder),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38.w,
            height: 38.w,
            decoration: const BoxDecoration(
              color: _kGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 20.sp,
            ),
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${coupon.code} applied',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: _kGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.sp,
                  ),
                ),
                Gap(2.h),
                Text(
                  coupon.description ??
                      'This coupon will be used when you place the order.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Previously there was no way to detach a coupon once applied —
          // reported bug: a coupon that becomes invalid (e.g. hits its
          // per-user limit) stayed stuck showing as "applied" with no
          // remove option anywhere in the app.
          TextButton(
            onPressed: onRemove,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: EdgeInsets.symmetric(horizontal: 8.w),
            ),
            child: Text(
              'Remove',
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ────────────────────────────────────────────────────────────

class _PremiumSectionHeader extends StatelessWidget {
  const _PremiumSectionHeader({
    required this.eyebrow,
    required this.eyebrowColor,
    required this.eyebrowIcon,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final Color eyebrowColor;
  final IconData eyebrowIcon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(5.w),
              decoration: BoxDecoration(
                color: eyebrowColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Icon(eyebrowIcon, size: 13.sp, color: eyebrowColor),
            ),
            Gap(7.w),
            Text(
              eyebrow,
              style: AppTextStyles.labelSmall.copyWith(
                color: eyebrowColor,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
                fontSize: 11.sp,
              ),
            ),
          ],
        ),
        Gap(6.h),
        Text(
          title,
          style: AppTextStyles.h2.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 19.sp,
          ),
        ),
        Gap(3.h),
        Text(
          subtitle,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12.5.sp,
          ),
        ),
      ],
    );
  }
}

// ─── Premium Coupon Card ───────────────────────────────────────────────────────

class _PremiumCouponCard extends StatelessWidget {
  const _PremiumCouponCard({
    required this.coupon,
    required this.subtotal,
    required this.isApplied,
    required this.isEligible,
    required this.isExpanded,
    required this.onToggleTerms,
    this.onApply,
  });

  final CouponEntity coupon;
  final double subtotal;
  final bool isApplied;
  final bool isEligible;
  final bool isExpanded;
  final VoidCallback onToggleTerms;
  final VoidCallback? onApply;

  String get _badgeMain => coupon.discountType == CouponDiscountType.PERCENTAGE
      ? '${coupon.discountValue.toStringAsFixed(0)}%'
      : coupon.discountValue.toInrCurrency;

  String get _saveLine {
    if (coupon.discountType == CouponDiscountType.PERCENTAGE &&
        coupon.maxDiscount > 0) {
      return 'Save up to ${coupon.maxDiscount.toInrCurrency}';
    }
    return 'Instant savings on this order';
  }

  Color get _leftBg {
    if (isApplied) return _kGreen;
    if (isEligible) return const Color(0xFFF3FCF4);
    return _kLocked;
  }

  Color get _leftIconColor {
    if (isApplied) return Colors.white;
    if (isEligible) return _kGreen;
    return _kLockedFg;
  }

  Color get _leftTextColor {
    if (isApplied) return Colors.white;
    return AppColors.textPrimary;
  }

  @override
  Widget build(BuildContext context) {
    final shortfall = coupon.minOrderAmount > subtotal
        ? coupon.minOrderAmount - subtotal
        : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(
          color: isApplied ? _kGreen.withValues(alpha: 0.6) : _kBorder,
          width: isApplied ? 1.5 : 1.0,
        ),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Left discount panel ──────────────────────────────────
            Container(
              width: 88.w,
              decoration: BoxDecoration(
                color: _leftBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppDimensions.radiusXl),
                  bottomLeft: Radius.circular(AppDimensions.radiusXl),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    isApplied
                        ? Icons.check_circle_rounded
                        : Icons.local_offer_rounded,
                    color: _leftIconColor,
                    size: 20.sp,
                  ),
                  Gap(8.h),
                  Text(
                    _badgeMain,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h2.copyWith(
                      color: _leftTextColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 20.sp,
                      height: 1.0,
                    ),
                  ),
                  Gap(2.h),
                  Text(
                    'OFF',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isApplied
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      fontSize: 10.sp,
                    ),
                  ),
                ],
              ),
            ),

            // Dashed separator
            const _DashedDivider(),

            // ── Right content ────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Code chip + status chip + Apply button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Wrap(
                            spacing: 8.w,
                            runSpacing: 6.h,
                            children: <Widget>[
                              _Chip(
                                text: coupon.code,
                                bg: const Color(0xFFF0F2F5),
                                fg: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              _Chip(
                                text: isApplied
                                    ? 'Applied'
                                    : isEligible
                                        ? 'Ready'
                                        : 'Locked',
                                bg: isApplied
                                    ? _kGreenLight
                                    : isEligible
                                        ? const Color(0xFFFFF3E0)
                                        : const Color(0xFFF0F2F5),
                                fg: isApplied
                                    ? _kGreen
                                    : isEligible
                                        ? const Color(0xFFBF6900)
                                        : _kLockedFg,
                              ),
                            ],
                          ),
                        ),
                        Gap(8.w),
                        _ApplyButton(
                          isApplied: isApplied,
                          isEligible: isEligible,
                          onTap: isEligible ? onApply : null,
                        ),
                      ],
                    ),
                    Gap(10.h),

                    // Title
                    Text(
                      coupon.description ??
                          'Use this coupon to reduce your final bill.',
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Gap(5.h),

                    // Save line
                    Text(
                      _saveLine,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Gap(10.h),

                    // Min cart + shortfall
                    Row(
                      children: <Widget>[
                        Icon(
                          PhosphorIcons.shoppingBag,
                          size: 13.sp,
                          color: AppColors.textSecondary,
                        ),
                        Gap(5.w),
                        Expanded(
                          child: Text(
                            'Min cart ${coupon.minOrderAmount.toInrCurrency}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (!isEligible && shortfall > 0)
                          Text(
                            'Add ${shortfall.toInrCurrency} more',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: const Color(0xFFE07800),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    Gap(12.h),

                    // View terms row
                    Divider(height: 1, color: _kDivider),
                    Gap(8.h),
                    InkWell(
                      onTap: onToggleTerms,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSm),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 4.h),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              isExpanded ? 'Hide terms' : 'View terms',
                              style: AppTextStyles.buttonSmall.copyWith(
                                color: _kGreen,
                                fontSize: 12.5.sp,
                              ),
                            ),
                            Gap(4.w),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_right_rounded,
                              size: 16.sp,
                              color: _kGreen,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Terms expanded
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      child: isExpanded
                          ? Padding(
                              padding: EdgeInsets.only(top: 8.h, bottom: 6.h),
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusMd,
                                  ),
                                  border: Border.all(color: _kBorder),
                                ),
                                child: Text(
                                  coupon.terms ??
                                      'Valid on one order. Cannot be clubbed with another coupon in the same checkout.',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Gap(4.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A vertical dashed separator between the left accent panel and the card body.
class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      child: CustomPaint(
        painter: const _DashPainter(color: _kBorder),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dashHeight = 5.0;
    const dashSpace = 4.0;
    double y = 0;
    final paint = Paint()..color = color;
    while (y < size.height) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, 1, dashHeight),
        paint,
      );
      y += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

// ─── Apply Button ──────────────────────────────────────────────────────────────

class _ApplyButton extends StatelessWidget {
  const _ApplyButton({
    required this.isApplied,
    required this.isEligible,
    this.onTap,
  });

  final bool isApplied;
  final bool isEligible;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (isApplied) {
      return Container(
        height: 38.h,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        decoration: BoxDecoration(
          color: _kGreenLight,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: _kGreenMid),
        ),
        alignment: Alignment.center,
        child: Text(
          'Applied',
          style: AppTextStyles.buttonSmall.copyWith(
            color: _kGreen,
            fontSize: 12.5.sp,
          ),
        ),
      );
    }

    return SizedBox(
      height: 38.h,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: isEligible ? _kGreen : _kLockedFg,
          side: BorderSide(
            color: isEligible ? _kGreen : _kBorder,
            width: 1.4,
          ),
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
        ),
        child: Text(
          'Apply',
          style: AppTextStyles.buttonSmall.copyWith(
            color: isEligible ? _kGreen : _kLockedFg,
            fontSize: 12.5.sp,
          ),
        ),
      ),
    );
  }
}

// ─── Premium Payment Offer Card ───────────────────────────────────────────────

class _PremiumPaymentOfferCard extends StatelessWidget {
  const _PremiumPaymentOfferCard({required this.offer});
  final PaymentOfferEntity offer;

  /// Returns a colour pair [bg, fg] keyed on the provider name.
  List<Color> _providerColors() {
    final name = offer.provider.trim().toLowerCase();
    if (name.contains('icici')) {
      return [const Color(0xFF003087), const Color(0xFFE8EFFF)];
    } else if (name.contains('hdfc')) {
      return [const Color(0xFF003366), const Color(0xFFE6EDF8)];
    } else if (name.contains('paytm')) {
      return [const Color(0xFF00BAF2), const Color(0xFFE0F7FD)];
    } else if (name.contains('sbi')) {
      return [const Color(0xFF003399), const Color(0xFFE0E8FF)];
    } else if (name.contains('axis')) {
      return [const Color(0xFFB40000), const Color(0xFFFDE8E8)];
    } else if (name.contains('upi') || name.contains('gpay')) {
      return [const Color(0xFF4285F4), const Color(0xFFE8F0FE)];
    }
    return [_kProviderBlue, const Color(0xFFE8EDF5)];
  }

  @override
  Widget build(BuildContext context) {
    final progress = offer.unlockProgress.clamp(0.0, 1.0).toDouble();
    final providerName = offer.provider.trim().isEmpty ? '₹' : offer.provider;
    final initial = providerName.substring(0, 1).toUpperCase();
    final colors = _providerColors();
    final avatarBg = colors[0];

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 14.h),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: _kBorder),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Provider avatar
              Container(
                width: 46.w,
                height: 46.w,
                decoration: BoxDecoration(
                  color: avatarBg,
                  borderRadius: BorderRadius.circular(13.r),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: AppTextStyles.h2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18.sp,
                    ),
                  ),
                ),
              ),
              Gap(12.w),

              // Title + description + chips
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      offer.title,
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Gap(4.h),
                    Text(
                      offer.description ??
                          'Online payment promotion on eligible carts.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Gap(8.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 6.h,
                      children: <Widget>[
                        _Chip(
                          text: providerName,
                          bg: _kProviderBluePill,
                          fg: _kProviderBluePillFg,
                        ),
                        _Chip(
                          text: 'Above ${offer.minOrderAmount.toInrCurrency}',
                          bg: const Color(0xFFF0F2F5),
                          fg: AppColors.textSecondary,
                        ),
                        if (offer.isPercentage && offer.cashbackPercent != null)
                          _Chip(
                            text: offer.maxCashback != null
                                ? '${offer.cashbackPercent!.toStringAsFixed(offer.cashbackPercent! % 1 == 0 ? 0 : 1)}% up to ${offer.maxCashback!.toInrCurrency}'
                                : '${offer.cashbackPercent!.toStringAsFixed(offer.cashbackPercent! % 1 == 0 ? 0 : 1)}% cashback',
                            bg: _kGreenLight,
                            fg: _kGreen,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Gap(10.w),

              // Reward badge
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10.w,
                  vertical: 8.h,
                ),
                decoration: BoxDecoration(
                  color: offer.isLocked ? _kGoldLight : _kGreenLight,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      offer.cashbackAmount.toInrCurrency,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: offer.isLocked ? _kGoldDark : _kGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.sp,
                      ),
                    ),
                    Text(
                      offer.isLocked ? 'Unlock' : 'Cashback',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: offer.isLocked ? _kGoldDark : _kGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Gap(14.h),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            child: LinearProgressIndicator(
              minHeight: 7.h,
              value: progress,
              backgroundColor: _kProgressBg,
              valueColor: AlwaysStoppedAnimation<Color>(
                offer.isLocked ? _kGold : _kGreen,
              ),
            ),
          ),

          Gap(10.h),

          // Lock status row
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  offer.isLocked
                      ? (offer.lockMessage ??
                          'Add a little more to unlock this payment offer.')
                      : 'Ready to claim on your next online payment.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11.5.sp,
                  ),
                ),
              ),
              Gap(10.w),
              _Chip(
                text: offer.isLocked ? 'Locked' : 'Live',
                bg: offer.isLocked ? _kGoldLight : _kGreenLight,
                fg: offer.isLocked ? _kGoldDark : _kGreen,
                fontWeight: FontWeight.w700,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Savings Info Card ─────────────────────────────────────────────────────────

class _SavingsInfoCard extends StatelessWidget {
  const _SavingsInfoCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _kInfoBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: _kInfoBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              PhosphorIcons.shieldCheckFill,
              size: 18.sp,
              color: _kGreen,
            ),
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'How savings are applied',
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: 13.5.sp,
                  ),
                ),
                Gap(4.h),
                Text(
                  'Coupons reduce your order total before payment. Bank and UPI offers are promotional benefits that may be credited by the payment partner after a successful online payment.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error Card ────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.icon,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 28.sp, color: AppColors.textTertiary),
          Gap(10.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Gap(14.h),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _kGreen),
              foregroundColor: _kGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: Text(
              'Retry',
              style: AppTextStyles.buttonSmall.copyWith(color: _kGreen),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty Card ────────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 30.sp, color: AppColors.textTertiary),
          Gap(10.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Gap(4.h),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Skeleton Cards ────────────────────────────────────────────────────────────

class _SkeletonCouponCard extends StatelessWidget {
  const _SkeletonCouponCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130.h,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 88.w,
            decoration: const BoxDecoration(
              color: Color(0xFFF0F2F5),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppDimensions.radiusXl),
                bottomLeft: Radius.circular(AppDimensions.radiusXl),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _SkeletonBox(width: 100.w, height: 16.h),
                  Gap(12.h),
                  _SkeletonBox(width: double.infinity, height: 13.h),
                  Gap(8.h),
                  _SkeletonBox(width: 150.w, height: 11.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBankCard extends StatelessWidget {
  const _SkeletonBankCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: <Widget>[
          _SkeletonBox(width: 46.w, height: 46.w, radius: 13),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SkeletonBox(width: 160.w, height: 14.h),
                Gap(8.h),
                _SkeletonBox(width: double.infinity, height: 12.h),
                Gap(6.h),
                _SkeletonBox(width: 120.w, height: 10.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 8.0,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.bgSkeleton,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ─── Chip ──────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    required this.bg,
    required this.fg,
    this.fontWeight = FontWeight.w600,
  });

  final String text;
  final Color bg;
  final Color fg;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          color: fg,
          fontWeight: fontWeight,
          fontSize: 11.sp,
        ),
      ),
    );
  }
}
