import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/bill_summary_entity.dart';

/// Premium upsell card promoting the real free-delivery threshold — the
/// only "unlock a perk by spending more" mechanism this app actually has
/// (there is no paid membership/subscription product on the backend, so
/// this deliberately never simulates one). Visually mirrors a paid-plan
/// upsell card (icon tile, headline, savings line, CTA) while every number
/// on it comes straight from [BillSummaryEntity.freeDelivery]/[deliveryFee].
///
/// Only rendered when there's a genuine amount left to unlock — see
/// [CartMembershipUpsellCard.isEligible].
class CartMembershipUpsellCard extends StatelessWidget {
  const CartMembershipUpsellCard({
    required this.summary,
    required this.onShopMore,
    super.key,
  });

  final BillSummaryEntity summary;
  final VoidCallback onShopMore;

  static bool isEligible(BillSummaryEntity summary) {
    final free = summary.freeDelivery;
    return free.enabled &&
        !summary.deliveryFee.isFree &&
        free.amountToUnlock > 0 &&
        summary.deliveryFee.amount > 0;
  }

  @override
  Widget build(BuildContext context) {
    if (!isEligible(summary)) {
      return const SizedBox.shrink();
    }

    final free = summary.freeDelivery;
    final deliveryFeeSaved = summary.deliveryFee.amount;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFFFF4E6), Color(0xFFFFFFFF)],
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          border: Border.all(color: const Color(0xFFFCE3B8)),
        ),
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: const Color(0xFFB45309),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                'Enjoy FREE Delivery — you\'re close!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            Gap(12.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: AppColors.brandRed,
                    borderRadius: BorderRadius.circular(13.r),
                  ),
                  child: Icon(
                    PhosphorIcons.moped,
                    color: Colors.white,
                    size: 22.sp,
                  ),
                ),
                Gap(12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'FreshCuts Free Delivery',
                        style: TextStyle(
                          fontSize: 14.5.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF171717),
                          fontFamily: 'Inter',
                        ),
                      ),
                      Gap(3.h),
                      Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF737684),
                            fontFamily: 'Inter',
                          ),
                          children: <InlineSpan>[
                            const TextSpan(text: 'Add '),
                            TextSpan(
                              text:
                                  '₹${free.amountToUnlock.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.brandRed,
                              ),
                            ),
                            const TextSpan(text: ' more to save '),
                            TextSpan(
                              text: '₹${deliveryFeeSaved.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.brandRed,
                              ),
                            ),
                            const TextSpan(text: ' on delivery'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Gap(8.w),
                _ShopMoreButton(onTap: onShopMore),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopMoreButton extends StatelessWidget {
  const _ShopMoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: AppColors.brandRed,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            'Shop More',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
    );
  }
}
