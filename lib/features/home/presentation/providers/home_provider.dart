import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/features/categories/domain/entities/category_entity.dart';
import 'package:bakaloo_flutter_app/features/categories/presentation/providers/category_provider.dart';
import 'package:bakaloo_flutter_app/features/home/domain/entities/banner_entity.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/providers/banner_provider.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/product_list_provider.dart';

part 'home_provider.g.dart';

class HomeScreenData {
  const HomeScreenData({
    required this.banners,
    required this.categories,
    required this.featuredProducts,
  });

  final List<BannerEntity> banners;
  final List<CategoryEntity> categories;
  final List<ProductEntity> featuredProducts;

  bool get hasContent =>
      banners.isNotEmpty ||
      categories.isNotEmpty ||
      featuredProducts.isNotEmpty;
}

@riverpod
Future<HomeScreenData> home(Ref ref) async {
  final futures = await Future.wait<Object?>(<Future<Object?>>[
    ref.watch(bannerProvider.future),
    ref.watch(categoryCollectionProvider.future),
    ref.watch(homeFeaturedProductsProvider.future),
  ]);

  return HomeScreenData(
    banners: futures[0] as List<BannerEntity>,
    categories: futures[1] as List<CategoryEntity>,
    featuredProducts: futures[2] as List<ProductEntity>,
  );
}

@riverpod
Future<List<ProductEntity>> homeNewArrivals(Ref ref) async {
  final result = await ref.read(getNewArrivalsUseCaseProvider).call(limit: 12);
  return result.fold((_) => const <ProductEntity>[], (data) => data);
}

@riverpod
Future<List<ProductEntity>> homeDeals(Ref ref) async {
  final result = await ref.read(getDealsUseCaseProvider).call(limit: 12);
  return result.fold((_) => const <ProductEntity>[], (data) => data);
}

@riverpod
Future<List<ProductEntity>> homeTrendingProducts(Ref ref) async {
  // PHASE 4C: Reduced limit 20 → 12. Sections cap trending at 8–12 items;
  // fetching 20 was wasted JSON decode work.
  // The redundant Dart re-sort is also removed: the backend query orders by
  // total_sold DESC already (confirmed in products.repository.js). Sorting
  // an already-sorted list is O(n log n) work on the UI thread for no gain.
  final result = await ref.read(getProductsUseCaseProvider).call(
        page: 1,
        limit: 12,
      );
  return result.fold(
    (_) => const <ProductEntity>[],
    (pageResult) => pageResult.items,
  );
}

@riverpod
Future<List<ProductEntity>> homeCategoryProducts(
  Ref ref,
  String categoryId,
) async {
  // PHASE 5C: Limit reduced 10 → 6.
  // The home category preview grid renders at most 6 products (2 rows × 3
  // columns). Fetching 10 was wasted network/decode work; the backend already
  // returns them sorted by featured+total_sold so the best products appear
  // first within the 6.
  final result = await ref.read(getCategoryProductsUseCaseProvider).call(
        categoryId: categoryId,
        page: 1,
        limit: 6,
      );
  return result.fold(
    (_) => const <ProductEntity>[],
    (pageResult) => pageResult.items,
  );
}
