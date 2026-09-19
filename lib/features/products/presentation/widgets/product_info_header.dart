import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/shared/widgets/rating_badge.dart';

/// Title block: eyebrow, name, description, admin-configured feature
/// badges (customBadges — real per-product data, not invented copy), then
/// the price + rating row. The wishlist toggle lives in the hero gallery's
/// own top bar now, not here (avoids showing it twice).
class ProductInfoHeader extends StatelessWidget {
  const ProductInfoHeader({
    required this.product,
    super.key,
  });

  final ProductEntity product;

  @override
  Widget build(BuildContext context) {
    final description = (product.description ?? '').trim();

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Farm Fresh',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: const Color(0xFF999999),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            product.name,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 26.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1414),
              height: 1.1,
            ),
          ),
          if (description.isNotEmpty) ...<Widget>[
            SizedBox(height: 8.h),
            Text(
              description,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF666666),
                height: 1.4,
              ),
            ),
          ],
          if (product.hasBadges) ...<Widget>[
            SizedBox(height: 14.h),
            Row(
              children: <Widget>[
                for (int i = 0;
                    i < product.customBadges.length;
                    i++) ...<Widget>[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 26.h,
                      margin: EdgeInsets.symmetric(horizontal: 12.w),
                      color: const Color(0xFFE5E5E5),
                    ),
                  Expanded(
                    child: _FeatureBadge(label: product.customBadges[i]),
                  ),
                ],
              ],
            ),
          ],
          SizedBox(height: 16.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '₹${product.effectivePrice.toStringAsFixed(0)}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandRed,
                  height: 1,
                ),
              ),
              SizedBox(width: 5.w),
              Padding(
                padding: EdgeInsets.only(bottom: 4.h),
                child: Text(
                  '/ ${product.displayUnit}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF999999),
                  ),
                ),
              ),
              const Spacer(),
              if (product.hasRating)
                RatingBadge(
                  rating: product.avgRating,
                  count: product.ratingCount,
                ),
            ],
          ),
          if (product.isOnSale) ...<Widget>[
            SizedBox(height: 4.h),
            RichText(
              text: TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: '₹${product.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF999999),
                      decoration: TextDecoration.lineThrough,
                      decorationColor: const Color(0xFF999999),
                      height: 1.2,
                    ),
                  ),
                  const TextSpan(text: ' MRP (incl. of all taxes)'),
                ],
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.sp,
                  color: const Color(0xFF999999),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  const _FeatureBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        PhosphorIcon(
          PhosphorIcons.leafBold,
          size: 15.sp,
          color: AppColors.brandRed,
        ),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1414),
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
