import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/product_detail_provider.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/recently_viewed_provider.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_pair_with_section.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_recently_viewed_section.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_similar_section.dart';

class PairWithWrapper extends ConsumerWidget {
  const PairWithWrapper({
    required this.productId,
    required this.enabled,
    required this.onProductTap,
    required this.onSeeAll,
    required this.onAddToCart,
    super.key,
  });

  final String productId;
  final bool enabled;
  final ValueChanged<ProductEntity> onProductTap;
  final VoidCallback onSeeAll;
  final ValueChanged<ProductEntity> onAddToCart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled) {
      return const SizedBox.shrink();
    }

    final async = ref.watch(pairWithProductsProvider(productId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) => products.isEmpty
          ? const SizedBox.shrink()
          : ProductPairWithSection(
              products: products,
              onProductTap: onProductTap,
              onSeeAll: onSeeAll,
              onAddToCart: onAddToCart,
            ),
    );
  }
}

class SimilarWrapper extends ConsumerWidget {
  const SimilarWrapper({
    required this.productId,
    required this.enabled,
    required this.onProductTap,
    required this.onSeeAll,
    required this.onAddToCart,
    super.key,
  });

  final String productId;
  final bool enabled;
  final ValueChanged<ProductEntity> onProductTap;
  final VoidCallback onSeeAll;
  final ValueChanged<ProductEntity> onAddToCart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled) {
      return const SizedBox.shrink();
    }

    final async = ref.watch(relatedProductsProvider(productId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => Padding(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
        child: Text(
          'Related items unavailable',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF666666),
          ),
        ),
      ),
      data: (products) => products.isEmpty
          ? const SizedBox.shrink()
          : ProductSimilarSection(
              products: products,
              onProductTap: onProductTap,
              onSeeAll: onSeeAll,
              onAddToCart: onAddToCart,
            ),
    );
  }
}

class RecentlyViewedWrapper extends ConsumerWidget {
  const RecentlyViewedWrapper({
    required this.productId,
    required this.enabled,
    required this.onProductTap,
    required this.onAddToCart,
    super.key,
  });

  final String productId;
  final bool enabled;
  final ValueChanged<ProductEntity> onProductTap;
  final ValueChanged<ProductEntity> onAddToCart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled) {
      return const SizedBox.shrink();
    }

    final async = ref.watch(recentlyViewedProductsProvider(productId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) => products.isEmpty
          ? const SizedBox.shrink()
          : ProductRecentlyViewedSection(
              products: products,
              onProductTap: onProductTap,
              onAddToCart: onAddToCart,
            ),
    );
  }
}
