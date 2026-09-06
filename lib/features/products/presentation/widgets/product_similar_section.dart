import 'package:flutter/material.dart';

import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_pair_with_section.dart';

class ProductSimilarSection extends StatelessWidget {
  const ProductSimilarSection({
    required this.products,
    this.onProductTap,
    this.onSeeAll,
    this.onAddToCart,
    super.key,
  });

  final List<ProductEntity> products;
  final ValueChanged<ProductEntity>? onProductTap;
  final VoidCallback? onSeeAll;
  final ValueChanged<ProductEntity>? onAddToCart;

  @override
  Widget build(BuildContext context) {
    return ProductRecommendationsStrip(
      title: 'Similar Products',
      products: products,
      onProductTap: onProductTap,
      onSeeAll: onSeeAll,
      onAddToCart: onAddToCart,
      showVariantTag: true,
      showAdBadge: true,
    );
  }
}
