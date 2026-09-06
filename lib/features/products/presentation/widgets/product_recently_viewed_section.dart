import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_pair_with_section.dart';

/// Standalone carousel (no "See all" link, unlike Pair With / Similar) —
/// built separately rather than reusing `ProductRecommendationsStrip` so
/// this feature stays purely additive with zero edits to that shared file.
class ProductRecentlyViewedSection extends StatelessWidget {
  const ProductRecentlyViewedSection({
    required this.products,
    this.onProductTap,
    this.onAddToCart,
    super.key,
  });

  final List<ProductEntity> products;
  final ValueChanged<ProductEntity>? onProductTap;
  final ValueChanged<ProductEntity>? onAddToCart;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: const Color(0xFFF5F5F5),
      padding: EdgeInsets.only(top: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Text(
              'Recently Viewed',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ),
          // Row + SingleChildScrollView instead of a height-locked ListView
          // so each card sizes to its own content — see the matching
          // comment in `product_pair_with_section.dart` for why.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(left: 16.w, right: 16.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final product in products)
                  RepaintBoundary(
                    child: ProductRecommendationCard(
                      product: product,
                      onTap: onProductTap == null
                          ? null
                          : () => onProductTap!(product),
                      onAdd: onAddToCart == null
                          ? null
                          : () => onAddToCart!(product),
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
