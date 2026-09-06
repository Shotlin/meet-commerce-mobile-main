import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/domain/usecases/get_product_detail.dart';
import 'package:bakaloo_flutter_app/features/products/domain/usecases/get_pair_with.dart';
import 'package:bakaloo_flutter_app/features/products/domain/usecases/get_related.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/product_list_provider.dart';

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
  final result =
      await ref.read(getProductDetailUseCaseProvider).call(productId);
  return result.fold(
    (failure) => throw StateError(failure.message),
    (product) => product,
  );
}

@riverpod
Future<List<ProductEntity>> relatedProducts(Ref ref, String productId) async {
  final result = await ref.read(getRelatedUseCaseProvider).call(productId);
  return result.fold((_) => const <ProductEntity>[], (products) => products);
}

@riverpod
Future<List<ProductEntity>> pairWithProducts(Ref ref, String productId) async {
  final result = await ref.read(getPairWithUseCaseProvider).call(productId);
  return result.fold((_) => const <ProductEntity>[], (products) => products);
}
