import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:bakaloo_flutter_app/shared/widgets/product_card.dart';

/// Standalone carousel (no "See all" link, unlike Pair With / Similar).
/// Renders the exact same [ProductCard] (`ProductCardVariant.premiumFresh`,
/// `ProductCardStyle.grid`) the Home screen's Premium Fresh product grid
/// uses — the same reused box UI as every other product-suggestion rail on
/// this screen, just without a header link.
class ProductRecentlyViewedSection extends StatelessWidget {
  const ProductRecentlyViewedSection({
    required this.products,
    this.onProductTap,
    super.key,
  });

  final List<ProductEntity> products;
  final ValueChanged<ProductEntity>? onProductTap;

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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 16.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final product in products)
                  Padding(
                    padding: EdgeInsets.only(right: 12.w),
                    child: RepaintBoundary(
                      child: SizedBox(
                        width: 170.w,
                        child: ProductCard(
                          product: product,
                          width: 170,
                          style: ProductCardStyle.grid,
                          variant: ProductCardVariant.premiumFresh,
                          showWishlist: true,
                          onTap: onProductTap == null
                              ? null
                              : () => onProductTap!(product),
                          onOptionsTap: product.hasMultipleOptions
                              ? () => showProductOptionsSheet(context, product)
                              : null,
                        ),
                      ),
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
