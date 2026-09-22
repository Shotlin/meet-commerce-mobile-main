import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/payment_offer_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_enhancement_providers.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/coupon_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/coupon_provider.dart';

/// "Offers & Benefits" section — a titled group of simple bordered rows
/// (Apply Coupon, Wallet balance, Payment offers), replacing the previous
/// single dense card. Same underlying data/actions as before (best-coupon
/// highlighting, apply/remove, payment-offer count) — only the shell is
/// lighter, matching the flatter row style used across the rest of this
/// redesign.
class CartOffersSection extends ConsumerWidget {
  const CartOffersSection({
    required this.onViewCoupons,
    super.key,
    this.showWalletTile = false,
    this.walletBalance = 0,
    this.useWallet = false,
    this.onToggleWallet,
  });

  final VoidCallback? onViewCoupons;

  /// Same gate as the bottom bar's wallet stripe (`showWalletStripe` in
  /// cart_screen.dart) — shown only when the admin allows wallet at all.
  final bool showWalletTile;
  final double walletBalance;
  final bool useWallet;
  final ValueChanged<bool>? onToggleWallet;

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
    final isApplied = highlightedCoupon != null &&
        checkoutState.appliedCoupon?.code == highlightedCoupon.code;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Offers & Benefits',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A1A),
              fontFamily: 'Inter',
            ),
          ),
          Gap(12.h),
          CartCouponTile(
            coupon: highlightedCoupon,
            isApplied: isApplied,
            subtotal: subtotal,
            onTap: onViewCoupons,
            onRemove: isApplied
                ? () => ref.read(checkoutProvider.notifier).removeCoupon()
                : null,
          ),
          if (showWalletTile) ...<Widget>[
            Gap(10.h),
            CartWalletTile(
              balance: walletBalance,
              value: useWallet,
              onChanged: onToggleWallet,
            ),
          ],
          if (offers.isNotEmpty) ...<Widget>[
            Gap(10.h),
            _PaymentOffersTile(count: offers.length, onTap: onViewCoupons),
          ],
        ],
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

/// Reusable bordered row: coupon icon, dynamic headline ("Save ₹40 with
/// WELCOME40" / "Add ₹X more to unlock" / "View all coupons"), Apply/Remove
/// action.
class CartCouponTile extends StatelessWidget {
  const CartCouponTile({
    required this.coupon,
    required this.isApplied,
    required this.subtotal,
    super.key,
    this.onTap,
    this.onRemove,
  });

  final CouponEntity? coupon;
  final bool isApplied;
  final double subtotal;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final title = coupon != null
        ? 'Save ${coupon!.discountAmount.toInrCurrency} with ${coupon!.code}'
        : 'Apply Coupon';
    final subtitle = coupon != null
        ? isApplied
            ? 'Applied to this checkout'
            : subtotal >= coupon!.minOrderAmount
                ? 'Ready for this basket'
                : 'Add ${(coupon!.minOrderAmount - subtotal).toInrCurrency} more to unlock'
        : 'Tap to browse live coupons';

    return _OfferTile(
      icon: Icons.local_offer_outlined,
      iconColor: AppColors.primaryGreen,
      iconBackground: AppColors.primaryGreenLight,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: isApplied
          ? _RemoveChip(onTap: onRemove)
          : Icon(
              Icons.chevron_right_rounded,
              size: 22.sp,
              color: AppColors.textTertiary,
            ),
    );
  }
}

/// Reusable bordered row: wallet icon, balance line, toggle switch — the
/// in-body equivalent of the sticky bottom bar's wallet stripe (same
/// `useWallet`/`onToggleWallet` state), for a customer scrolling the page
/// rather than looking at the checkout dock.
class CartWalletTile extends StatelessWidget {
  const CartWalletTile({
    required this.balance,
    required this.value,
    super.key,
    this.onChanged,
  });

  final double balance;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return _OfferTile(
      icon: Icons.account_balance_wallet_outlined,
      iconColor: AppColors.brandRed,
      iconBackground: AppColors.brandRedSurface,
      title: 'FreshCuts Wallet Balance: ${balance.toInrCurrency}',
      subtitle: balance > 0
          ? 'Use wallet balance for this order'
          : 'Top up to pay faster next time',
      trailing: Switch(
        value: value && balance > 0,
        onChanged: balance > 0 ? onChanged : null,
        activeThumbColor: AppColors.brandRed,
      ),
    );
  }
}

class _PaymentOffersTile extends StatelessWidget {
  const _PaymentOffersTile({required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _OfferTile(
      icon: Icons.credit_card_rounded,
      iconColor: const Color(0xFF2B6CFF),
      iconBackground: const Color(0xFFEAF1FF),
      title: 'View payment offers',
      subtitle: count == 1 ? '1 payment offer available' : '$count payment offers available',
      onTap: onTap,
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 22.sp,
        color: AppColors.textTertiary,
      ),
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: const Color(0xFFEDEDED)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, size: 20.sp, color: iconColor),
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
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                        fontFamily: 'Inter',
                      ),
                    ),
                    Gap(2.h),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF888888),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[Gap(8.w), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoveChip extends StatelessWidget {
  const _RemoveChip({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brandRed,
        side: const BorderSide(color: AppColors.brandRed, width: 1.2),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
      child: Text(
        'Remove',
        style: TextStyle(
          fontSize: 12.5.sp,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}
