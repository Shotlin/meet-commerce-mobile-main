import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/features/cart/domain/entities/bill_summary_entity.dart';

/// Savings banner — "Yay! You saved ₹44 on this order" plus, when the
/// backend has a genuine next reward to tease (a cart-milestone tier or the
/// free-delivery threshold), a second line: "Shop for ₹34 more to save
/// ₹50 | FREEDEL". Both numbers are real (never fabricated) — sourced
/// straight from [BillSummaryEntity.cartMilestone]/[BillSummaryEntity.
/// freeDelivery], the same fields the bill-summary card's own progress hint
/// already uses.
class CartSavingsBanner extends StatefulWidget {
  const CartSavingsBanner({
    required this.savingsTotal,
    super.key,
    this.nextRewardLabel,
  });

  final double savingsTotal;

  /// Pre-formatted "Shop for ₹X more to save ₹Y | CODE" style line — see
  /// [CartSavingsBanner.nextRewardLabelFor] for how callers build it.
  final String? nextRewardLabel;

  /// Builds the second-line nudge from real bill-summary data: prefers the
  /// next cart-milestone tier (admin-configured reward ladder) and falls
  /// back to the free-delivery threshold when no milestone is configured.
  /// Returns null when the cart already has nothing left to unlock.
  static String? nextRewardLabelFor(BillSummaryEntity summary) {
    final nextTier = summary.cartMilestone.next;
    if (nextTier != null && nextTier.amountToUnlock > 0) {
      final reward = nextTier.rewardType == 'CASHBACK'
          ? 'cashback'
          : nextTier.name.isNotEmpty
              ? nextTier.name
              : 'a reward';
      return 'Shop for ₹${nextTier.amountToUnlock.toStringAsFixed(0)} more to unlock $reward';
    }

    final free = summary.freeDelivery;
    if (free.enabled && !summary.deliveryFee.isFree && free.amountToUnlock > 0) {
      return 'Shop for ₹${free.amountToUnlock.toStringAsFixed(0)} more for FREE delivery';
    }

    return null;
  }

  @override
  State<CartSavingsBanner> createState() => _CartSavingsBannerState();
}

class _CartSavingsBannerState extends State<CartSavingsBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.savingsTotal <= 0) {
      return const SizedBox.shrink();
    }

    final nextReward = widget.nextRewardLabel;

    return Material(
      color: const Color(0xFFF0FFF4),
      child: InkWell(
        onTap: () {
          setState(() {
            _expanded = !_expanded;
          });
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF333333),
                          fontFamily: 'Inter',
                        ),
                        children: <InlineSpan>[
                          const TextSpan(text: 'Yay! You '),
                          TextSpan(
                            text:
                                'saved ₹${widget.savingsTotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0AC26B),
                              fontFamily: 'Inter',
                            ),
                          ),
                          const TextSpan(text: ' on this order'),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18.sp,
                    color: const Color(0xFF0AC26B),
                  ),
                ],
              ),
              if (nextReward != null) ...<Widget>[
                SizedBox(height: 4.h),
                Text(
                  nextReward,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E7A3A),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: EdgeInsets.only(top: 10.h),
                  child: Text(
                    'MRP discounts and waived fees are already reflected in your total.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF4D4D4D),
                      height: 1.4,
                      fontFamily: 'Inter',
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
