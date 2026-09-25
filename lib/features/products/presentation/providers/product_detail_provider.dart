import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/domain/usecases/get_product_detail.dart';
import 'package:bakaloo_flutter_app/features/products/domain/usecases/get_pair_with.dart';
import 'package:bakaloo_flutter_app/features/products/domain/usecases/get_related.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/product_list_provider.dart';

import 'package:bakaloo_flutter_app/core/providers/price_mode_provider.dart';
import 'package:bakaloo_flutter_app/core/providers/storefront_scope_provider.dart';
import 'package:bakaloo_flutter_app/core/utils/cache_for.dart';

part 'product_detail_provider.g.dart';

final getProductDetailUseCaseProvider = Provider<GetProductDetailUseCase>((
  Ref ref,
) {
  return GetProductDetailUseCase(ref.watch(productRepositoryProvider));
});

final getRelatedUseCaseProvider = Provider<GetRelatedUseCase>((Ref ref) {
  return GetRelatedUseCase(ref.watch(productRepositoryProvider));
});

final getPairWithUseCaseProvider = Provider<GetPairWithUseCase>((Ref ref) {
  return GetPairWithUseCase(ref.watch(productRepositoryProvider));
});

@riverpod
Future<ProductEntity> productDetail(Ref ref, String productId) async {
  ref.watch(priceModeProvider);
  // Price/stock are resolved server-side from the caller's active shop, so
  // a shop/location switch must force a refetch of an already-cached
  // product — never silently keep showing the previous store's price.
  ref.watch(storefrontScopeProvider);
  // Revisiting the same product within 5 minutes (tapping back from a
  // recommendation rail, or re-opening from Recently Viewed) shows the
  // already-fetched product instantly instead of a full reload.
  ref.cacheFor(const Duration(minutes: 5));
  final result =
      await ref.read(getProductDetailUseCaseProvider).call(productId);
  return result.fold(
    (failure) => throw StateError(failure.message),
    (product) => product,
  );
}

@riverpod
Future<List<ProductEntity>> relatedProducts(Ref ref, String productId) async {
  ref.watch(storefrontScopeProvider);
  ref.cacheFor(const Duration(minutes: 5));
  final result = await ref.read(getRelatedUseCaseProvider).call(productId);
  return result.fold((_) => const <ProductEntity>[], (products) => products);
}

@riverpod
Future<List<ProductEntity>> pairWithProducts(Ref ref, String productId) async {
  ref.watch(storefrontScopeProvider);
  ref.cacheFor(const Duration(minutes: 5));
  final result = await ref.read(getPairWithUseCaseProvider).call(productId);
  return result.fold((_) => const <ProductEntity>[], (products) => products);
}
