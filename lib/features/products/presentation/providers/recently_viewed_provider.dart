import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/constants/app_constants.dart';
import 'package:bakaloo_flutter_app/features/products/data/local/recently_viewed_datasource.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/product_detail_provider.dart';

part 'recently_viewed_provider.g.dart';

final recentlyViewedDataSourceProvider = Provider<RecentlyViewedDataSource>((
  Ref ref,
) {
  return const RecentlyViewedDataSource();
});

@riverpod
class RecentlyViewedNotifier extends _$RecentlyViewedNotifier {
  @override
  List<String> build() {
    return ref.read(recentlyViewedDataSourceProvider).getAll();
  }

  Future<void> recordView(String productId) async {
    await ref.read(recentlyViewedDataSourceProvider).save(productId);
    state = ref.read(recentlyViewedDataSourceProvider).getAll();
  }

  void refresh() {
    state = ref.read(recentlyViewedDataSourceProvider).getAll();
  }
}

/// Live product entities for the recently-viewed carousel, excluding the
/// product currently being viewed. Each id is fetched live via the same
/// single-product endpoint the rest of the detail screen uses (not the
/// locally-cached snapshot), so price/stock/images are always current —
/// any id that fails to load (deleted) or is out of stock is dropped
/// rather than shown stale/unavailable.
@riverpod
Future<List<ProductEntity>> recentlyViewedProducts(
  Ref ref,
  String excludeProductId,
) async {
  final ids = ref
      .watch(recentlyViewedProvider)
      .where((id) => id != excludeProductId)
      .take(AppConstants.maxRecentlyViewed)
      .toList();

  if (ids.isEmpty) {
    return const <ProductEntity>[];
  }

  final results = await Future.wait(
    ids.map((id) async {
      try {
        return await ref.read(productDetailProvider(id).future);
      } catch (_) {
        return null;
      }
    }),
  );

  return results
      .whereType<ProductEntity>()
      .where((product) => product.stockQuantity > 0)
      .toList();
}
