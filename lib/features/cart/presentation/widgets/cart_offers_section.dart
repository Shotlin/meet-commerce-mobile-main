import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/coupon_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/coupon_provider.dart';

/// "Offers & Benefits" section — two compact single-line bordered rows
/// (Apply Coupon, FreshCuts Wallet balance). Same underlying data/actions
/// as before (best-coupon highlighting, apply/remove, real wallet balance
/// and the same `useWallet` state `CheckoutScreen`'s own wallet stripe
/// reads/writes) — only the shell is lighter and more compact.
class CartOffersSection extends ConsumerWidget {
  const CartOffersSection({
    required this.onViewCoupons,
    super.key,
    this.showWalletTile = false,
    this.walletBalance = 0,
  });

  final VoidCallback? onViewCoupons;

  /// Shown only when the admin allows wallet at all (even at zero balance —
  /// same gate `CheckoutScreen` uses for its own wallet stripe).
  final bool showWalletTile;
  final double walletBalance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couponsAsync = ref.watch(availableCouponsProvider);
    final checkoutState = ref.watch(checkoutProvider);
    final subtotal = ref.read(checkoutProvider.notifier).subtotal;

    final coupons = couponsAsync.asData?.value ?? const <CouponEntity>[];

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
              value: checkoutState.useWallet,
              onChanged: walletBalance > 0
                  ? (value) =>
                      ref.read(checkoutProvider.notifier).setUseWallet(value)
                  : null,
            ),
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

/// Compact single-line bordered row: green coupon icon, dynamic headline
/// ("Save ₹40 with WELCOME40" / "Apply Coupon"), Apply/Remove action.
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

  static const Color _green = Color(0xFF0AC26B);

  @override
  Widget build(BuildContext context) {
    final title = coupon == null
        ? 'Apply Coupon'
        : isApplied
            ? 'Applied ${coupon!.code} — saved ${coupon!.discountAmount.toInrCurrency}'
            : subtotal >= coupon!.minOrderAmount
                ? 'Save ${coupon!.discountAmount.toInrCurrency} with ${coupon!.code}'
                : 'Add ${(coupon!.minOrderAmount - subtotal).toInrCurrency} more to unlock ${coupon!.code}';

    return _OfferTile(
      icon: Icons.sell_rounded,
      iconColor: Colors.white,
      iconBackground: _green,
      borderColor: _green,
      title: title,
      titleColor: const Color(0xFF1A1A1A),
      onTap: onTap,
      trailing: isApplied
          ? _RemoveChip(onTap: onRemove)
          : Icon(
              Icons.chevron_right_rounded,
              size: 22.sp,
              color: _green,
            ),
    );
  }
}

/// Compact single-line bordered row: wallet icon, real balance, ON/OFF
/// toggle. Wired to the exact same `useWallet` state `CheckoutScreen`'s own
/// wallet stripe reads and writes — flipping it here changes the same real
/// order math, not a separate/duplicate wallet flag.
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
      iconColor: const Color(0xFF555555),
      iconBackground: const Color(0xFFF2F2F2),
      borderColor: const Color(0xFFE2E2E2),
      title: 'FreshCuts Wallet Balance: ${balance.toInrCurrency}',
      titleColor: const Color(0xFF1A1A1A),
      trailing: Switch(
        value: value && balance > 0,
        onChanged: onChanged,
        activeThumbColor: AppColors.brandRed,
      ),
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.borderColor,
    required this.title,
    required this.titleColor,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Color borderColor;
  final String title;
  final Color titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: borderColor, width: 1.3),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 30.w,
                height: 30.w,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 15.sp, color: iconColor),
              ),
              Gap(10.w),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    fontFamily: 'Inter',
                  ),
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
