import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:bakaloo_flutter_app/shared/widgets/product_card.dart';

class ProductPairWithSection extends StatelessWidget {
  const ProductPairWithSection({
    required this.products,
    this.onProductTap,
    this.onSeeAll,
    super.key,
  });

  final List<ProductEntity> products;
  final ValueChanged<ProductEntity>? onProductTap;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return ProductRecommendationsStrip(
      title: 'Pair it with',
      products: products,
      onProductTap: onProductTap,
      onSeeAll: onSeeAll,
    );
  }
}

/// Shared "recommendation rail" shell used by Pair It With / Similar
/// Products / Recently Viewed on the product detail screen. Renders the
/// exact same [ProductCard] (`ProductCardVariant.premiumFresh`,
/// `ProductCardStyle.grid`) the Home screen's Premium Fresh product grid and
/// the cart's own recommendation rail already use — one box UI everywhere a
/// product is suggested, add-to-cart/quantity/wishlist/multi-option handling
/// included, just laid out as a horizontal rail instead of a wrapped grid.
class ProductRecommendationsStrip extends StatelessWidget {
  const ProductRecommendationsStrip({
    required this.title,
    required this.products,
    this.onProductTap,
    this.onSeeAll,
    super.key,
  });

  final String title;
  final List<ProductEntity> products;
  final ValueChanged<ProductEntity>? onProductTap;
  final VoidCallback? onSeeAll;

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
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                if (onSeeAll != null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onSeeAll,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'See all',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.pdViolet,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(width: 2.w),
                        PhosphorIcon(
                          PhosphorIcons.caretRight,
                          size: 14.sp,
                          color: AppColors.pdViolet,
                        ),
                      ],
                    ),
                  ),
              ],
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
