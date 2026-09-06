import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/payment_offer_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_enhancement_providers.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/coupon_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/coupon_provider.dart';

class CartCouponsOffers extends ConsumerWidget {
  const CartCouponsOffers({
    super.key,
    this.onViewCoupons,
  });

  final VoidCallback? onViewCoupons;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couponsAsync = ref.watch(availableCouponsProvider);
    final offersAsync = ref.watch(paymentOffersProvider);
    final checkoutState = ref.watch(checkoutProvider);
    final subtotal = ref.read(checkoutProvider.notifier).subtotal;

    final coupons = couponsAsync.asData?.value ?? const <CouponEntity>[];
    final offers = offersAsync.asData?.value ?? const <PaymentOfferEntity>[];

    final highlightedCoupon =
        checkoutState.appliedCoupon ?? _pickBestCoupon(coupons, subtotal);
    final isHighlightedCouponApplied = highlightedCoupon != null &&
        checkoutState.appliedCoupon?.code == highlightedCoupon.code;
    final couponHeadline = highlightedCoupon != null
        ? 'Save ${highlightedCoupon.displayDiscount} with ${highlightedCoupon.code}'
        : 'View all coupons';
    final couponSubline = highlightedCoupon != null
        ? isHighlightedCouponApplied
            ? 'Applied to this checkout'
            : subtotal >= highlightedCoupon.minOrderAmount
                ? 'Ready for this basket'
                : 'Add ${highlightedCoupon.shortfall(subtotal).toInrCurrency} more to unlock'
        : 'Tap to browse live coupons';

    final offersSubline = offersAsync.when(
      loading: () => 'Loading payment offers',
      error: (_, __) => 'Payment offers unavailable',
      data: (value) {
        if (value.isEmpty) {
          return 'No payment offers right now';
        }
        return value.length == 1
            ? '1 payment offer available'
            : '${value.length} payment offers available';
      },
    );

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          border: Border.all(color: const Color(0xFFE9ECEF)),
          boxShadow: const <BoxShadow>[AppShadows.cardShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _TopBanner(
              text: 'Apply coupons + payment offers & save more',
            ),
            Gap(14.h),
            Text(
              'Coupons & offers',
              style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w800),
            ),
            Gap(14.h),
            _ActionRow(
              icon: Icons.local_offer_outlined,
              iconBackground: AppColors.primaryGreenLight,
              iconColor: AppColors.primaryGreen,
              title: couponHeadline,
              subtitle: couponSubline,
              // Previously this always said "Apply" and only ever opened the
              // coupon list — even while a coupon was already applied, with
              // no way to detach it from here. Reported bug: a coupon that
              // stops being usable (e.g. hits its per-user limit) had no
              // remove affordance, so it stayed stuck showing as applied.
              actionLabel: isHighlightedCouponApplied ? 'Remove' : 'Apply',
              actionOnTap: isHighlightedCouponApplied
                  ? () => ref.read(checkoutProvider.notifier).removeCoupon()
                  : onViewCoupons,
              onTap: onViewCoupons,
              actionOutlined: true,
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              child: const Divider(height: 1, color: Color(0xFFEDEDED)),
            ),
            _ActionRow(
              icon: Icons.credit_card_rounded,
              iconBackground: const Color(0xFFEAF1FF),
              iconColor: const Color(0xFF2B6CFF),
              title: 'View payment offers',
              subtitle: offersSubline,
              onTap: onViewCoupons,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (offers.isNotEmpty)
                    Text(
                      offers.length.toString(),
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (offers.isNotEmpty) Gap(4.w),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22.sp,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static CouponEntity? _pickBestCoupon(
    List<CouponEntity> coupons,
    double subtotal,
  ) {
    if (coupons.isEmpty) {
      return null;
    }

    final eligibleCoupons =
        coupons.where((coupon) => subtotal >= coupon.minOrderAmount).toList();
    final sortedCoupons = List<CouponEntity>.of(
      eligibleCoupons.isNotEmpty ? eligibleCoupons : coupons,
    )..sort((a, b) => b.discountAmount.compareTo(a.discountAmount));
    return sortedCoupons.first;
  }
}

class _TopBanner extends StatelessWidget {
  const _TopBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9E7FF)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: const Color(0xFF2B78FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'NEW',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 10.sp,
              ),
            ),
          ),
          Gap(10.w),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: const Color(0xFF2A5FA8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.actionOnTap,
    this.trailing,
    this.onTap,
    this.actionOutlined = false,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? actionOnTap;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool actionOutlined;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: <Widget>[
        Container(
          width: 44.w,
          height: 44.w,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE7E7E7)),
          ),
          child: Icon(icon, size: 22.sp, color: iconColor),
        ),
        Gap(12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.sp,
                ),
              ),
              Gap(3.h),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null) ...<Widget>[
          Gap(10.w),
          _ActionButton(
            label: actionLabel!,
            onTap: actionOnTap,
            outlined: actionOutlined,
          ),
        ] else if (trailing != null) ...<Widget>[
          trailing!,
        ],
      ],
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 2.h),
          child: content,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onTap,
    required this.outlined,
  });

  final String label;
  final VoidCallback? onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final foreground = outlined ? const Color(0xFFC33B74) : Colors.white;
    final background = outlined ? Colors.white : AppColors.primaryGreen;
    final borderColor = outlined ? const Color(0xFFC33B74) : Colors.transparent;

    return SizedBox(
      height: 42.h,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          side: BorderSide(color: borderColor, width: outlined ? 1.4 : 0),
          padding: EdgeInsets.symmetric(horizontal: 18.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.buttonMedium.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

extension on CouponEntity {
  String get displayDiscount => discountAmount.toInrCurrency;

  double shortfall(double subtotal) {
    final gap = minOrderAmount - subtotal;
    return gap > 0 ? gap : 0;
  }
}
