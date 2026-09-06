import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/bill_summary_entity.dart';

/// A positive "add X to unlock this offer" nudge for a first-time customer
/// whose cart doesn't yet qualify for any active first-order offer — e.g.
/// an all-dairy cart shown "Add ₹150 of Fresh Vegetables to unlock Free
/// Delivery!" instead of the offer just silently never appearing anywhere.
/// Sits between Coupons & Offers and Bill Summary; only rendered when the
/// backend actually has something to tease (see [BillSummaryEntity.
/// firstTimeOfferTeaser] — always null once an offer is already applied).
class CartFirstTimeOfferTeaser extends StatelessWidget {
  const CartFirstTimeOfferTeaser({required this.teaser, super.key});

  final FirstTimeOfferTeaserInfo teaser;

  /// Splits [teaser.message] on ₹-amount tokens (e.g. "₹20", "₹51") so they
  /// can render bold and in the accent color while the rest of the sentence
  /// stays a regular-weight, softer gray — the amounts are the one thing a
  /// customer actually needs to scan for, and a flat single-weight paragraph
  /// buried them in a wall of category names.
  List<InlineSpan> _highlightedMessage(TextStyle base, TextStyle amount) {
    final pattern = RegExp(r'₹[\d,]+(?:\.\d+)?');
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in pattern.allMatches(teaser.message)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(text: teaser.message.substring(cursor, match.start)),
        );
      }
      spans.add(TextSpan(text: match.group(0), style: amount));
      cursor = match.end;
    }
    if (cursor < teaser.message.length) {
      spans.add(TextSpan(text: teaser.message.substring(cursor)));
    }
    return spans.isEmpty
        ? <InlineSpan>[TextSpan(text: teaser.message)]
        : spans;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFFF2FBF5),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.primaryGreen.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 42.w,
              height: 42.w,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                PhosphorIcons.giftFill,
                color: Colors.white,
                size: 21.sp,
              ),
            ),
            Gap(12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 7.w,
                      vertical: 2.5.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'FIRST ORDER',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 9.5.sp,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Gap(6.h),
                  Text(
                    teaser.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.sp,
                    ),
                  ),
                  Gap(4.h),
                  Text.rich(
                    TextSpan(
                      children: _highlightedMessage(
                        AppTextStyles.bodyMedium.copyWith(
                          color: const Color(0xFF4A7C58),
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          fontSize: 12.5.sp,
                        ),
                        AppTextStyles.bodyMedium.copyWith(
                          color: const Color(0xFF1E7A3A),
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                          fontSize: 12.5.sp,
                        ),
                      ),
                    ),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: const Color(0xFF4A7C58),
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      fontSize: 12.5.sp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
