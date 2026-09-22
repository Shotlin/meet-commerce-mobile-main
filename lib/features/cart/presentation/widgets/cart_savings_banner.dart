import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/features/checkout/domain/entities/coupon_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:bakaloo_flutter_app/features/checkout/presentation/providers/coupon_provider.dart';

/// Savings banner — "You have saved ₹44!" plus, only when a real coupon is
/// genuinely close to unlocking, a second line: "Shop for ₹34 more to save
/// ₹50 | 20FLAT". Every number on both lines comes straight from cart/offer
/// data (`billSummary.savings.total`, `availableCouponsProvider`,
/// `checkoutProvider`'s live subtotal) — nothing here is hardcoded, and the
/// second line simply doesn't render when there's no such coupon.
class CartSavingsBanner extends ConsumerWidget {
  const CartSavingsBanner({required this.savingsTotal, super.key});

  final double savingsTotal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (savingsTotal <= 0) {
      return const SizedBox.shrink();
    }

    final nextRewardLine = _nextCouponTease(ref);

    return Container(
      width: double.infinity,
      color: const Color(0xFFEAFBEF),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.all_inclusive_rounded,
                size: 18.sp,
                color: const Color(0xFFFFA31A),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF222222),
                      fontFamily: 'Inter',
                    ),
                    children: <InlineSpan>[
                      const TextSpan(text: 'You have saved '),
                      TextSpan(
                        text: '₹${savingsTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0AC26B),
                        ),
                      ),
                      const TextSpan(text: '!'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (nextRewardLine != null) ...<Widget>[
            SizedBox(height: 3.h),
            Padding(
              padding: EdgeInsets.only(left: 26.w),
              child: Text(
                nextRewardLine,
                style: TextStyle(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF444444),
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// "Shop for ₹X more to save ₹Y | CODE" — built from the nearest coupon
  /// the customer hasn't unlocked yet (smallest shortfall to its
  /// `minOrderAmount`, ties broken by the larger discount). Cashback/
  /// free-delivery coupons (`discountAmount == 0`) don't fit the "save ₹Y"
  /// phrasing, so they're excluded; an already-applied coupon has nothing
  /// left to tease. Returns null — hiding the line entirely — when no such
  /// coupon exists.
  String? _nextCouponTease(WidgetRef ref) {
    final coupons = ref.watch(availableCouponsProvider).asData?.value ??
        const <CouponEntity>[];
    if (coupons.isEmpty) {
      return null;
    }

    final appliedCode = ref.watch(
      checkoutProvider.select((s) => s.appliedCoupon?.code),
    );
    final subtotal = ref.watch(checkoutProvider.notifier).subtotal;

    CouponEntity? best;
    double bestShortfall = double.infinity;
    for (final coupon in coupons) {
      if (coupon.code == appliedCode || coupon.discountAmount <= 0) {
        continue;
      }
      final shortfall = coupon.minOrderAmount - subtotal;
      if (shortfall <= 0) {
        continue;
      }
      if (shortfall < bestShortfall ||
          (shortfall == bestShortfall &&
              (best == null || coupon.discountAmount > best.discountAmount))) {
        best = coupon;
        bestShortfall = shortfall;
      }
    }

    if (best == null) {
      return null;
    }

    return 'Shop for ₹${bestShortfall.toStringAsFixed(0)} more to save '
        '₹${best.discountAmount.toStringAsFixed(0)} | ${best.code}';
  }
}
