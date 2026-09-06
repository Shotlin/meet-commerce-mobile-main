// PHASE 2C/2D: Memoized default product pool provider.
//
// Computes the merged default product pool exactly once per Riverpod build
// cycle. All dynamic section builders that previously called
// _resolveDefaultProductPool() — iterating the full tabHome category section
// products N times for each section — now watch this single provider instead.
//
// Invalidation is automatic: the Provider depends on
//   • selectedTabHomeContentProvider  (tab switch / data refresh)
//   • homeFeaturedProductsProvider    (featured products refresh)
//   • homeDealsProvider               (deals refresh)
//   • homeTrendingProductsProvider    (trending refresh)
// so any of those changing causes a single re-merge and all section slots get
// the updated pool on their next build.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/providers/banner_provider.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/providers/home_provider.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';

final memoizedDefaultProductPoolProvider = Provider<List<ProductEntity>>(
  (Ref ref) {
    final tabHome =
        ref.watch(selectedTabHomeContentProvider).asData?.value;
    final featured =
        ref.watch(homeFeaturedProductsProvider).asData?.value ??
            const <ProductEntity>[];
    final deals =
        ref.watch(homeDealsProvider).asData?.value ?? const <ProductEntity>[];
    final trending =
        ref.watch(homeTrendingProductsProvider).asData?.value ??
            const <ProductEntity>[];

    // Build category section product list once — not per-section.
    final List<ProductEntity> categorySectionProducts;
    if (tabHome != null && tabHome.categorySections.isNotEmpty) {
      final buffer = <ProductEntity>[];
      for (final section in tabHome.categorySections) {
        for (final product in section.products) {
          if (product.inStock) buffer.add(product);
        }
      }
      categorySectionProducts = buffer;
    } else {
      categorySectionProducts = const <ProductEntity>[];
    }

    return _mergePoolUnique(<List<ProductEntity>>[
      tabHome?.seasonalProducts ?? const <ProductEntity>[],
      categorySectionProducts,
      tabHome?.featuredProducts ?? const <ProductEntity>[],
      tabHome?.dealProducts ?? const <ProductEntity>[],
      tabHome?.trendingProducts ?? const <ProductEntity>[],
      featured,
      deals,
      trending,
    ]);
  },
);

/// Merge helper — same logic as _mergeUniqueProducts in section_registry but
/// kept here to avoid circular imports between section_registry ↔
/// dynamic_home_sections.
List<ProductEntity> _mergePoolUnique(List<List<ProductEntity>> groups) {
  final seen = <String>{};
  final seenFamilies = <String>{};
  final merged = <ProductEntity>[];
  for (final group in groups) {
    for (final product in group) {
      if (!product.inStock) continue;
      if (product.productFamilyId != null &&
          product.productFamilyId!.isNotEmpty) {
        if (!seenFamilies.add(product.productFamilyId!)) continue;
      }
      if (seen.add(product.id)) merged.add(product);
    }
  }
  return merged;
}
