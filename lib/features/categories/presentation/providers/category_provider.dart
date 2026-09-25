import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/providers/storefront_scope_provider.dart';
import 'package:bakaloo_flutter_app/core/utils/cache_for.dart';
import 'package:bakaloo_flutter_app/features/categories/data/datasources/category_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/categories/data/local/category_local_datasource.dart';
import 'package:bakaloo_flutter_app/features/categories/data/repositories/category_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/categories/domain/entities/category_entity.dart';
import 'package:bakaloo_flutter_app/features/categories/domain/repositories/category_repository.dart';
import 'package:bakaloo_flutter_app/features/categories/domain/usecases/get_categories.dart';
import 'package:bakaloo_flutter_app/features/categories/domain/usecases/get_category_products.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';

part 'category_provider.g.dart';

final categoryRemoteDataSourceProvider = Provider<CategoryRemoteDataSource>((
  Ref ref,
) {
  return CategoryRemoteDataSource(ref.watch(apiClientProvider));
});

final categoryLocalDataSourceProvider = Provider<CategoryLocalDataSource>((
  Ref ref,
) {
  return const CategoryLocalDataSource();
});

final categoryRepositoryProvider = Provider<CategoryRepository>((Ref ref) {
  return CategoryRepositoryImpl(
    remoteDataSource: ref.watch(categoryRemoteDataSourceProvider),
    localDataSource: ref.watch(categoryLocalDataSourceProvider),
  );
});

final getCategoriesUseCaseProvider = Provider<GetCategoriesUseCase>((Ref ref) {
  return GetCategoriesUseCase(ref.watch(categoryRepositoryProvider));
});

final getCategoryProductsUseCaseProvider =
    Provider<GetCategoryProductsUseCase>((Ref ref) {
  return GetCategoryProductsUseCase(ref.watch(categoryRepositoryProvider));
});

@riverpod
Future<List<CategoryEntity>> categoryCollection(Ref ref) async {
  // The category list itself is never shop-scoped server-side (same list
  // for every shop), so — unlike the providers below — this deliberately
  // does not watch storefrontScopeProvider; only the cache lifetime matters
  // here, so reopening Search/Categories shows the list instantly instead
  // of re-fetching a list that virtually never changes mid-session.
  ref.cacheFor(const Duration(minutes: 15));
  final result = await ref.read(getCategoriesUseCaseProvider).call();
  return result.fold((_) => const <CategoryEntity>[], (data) => data);
}

@immutable
class CategoryProductShelfRequest {
  const CategoryProductShelfRequest({
    required this.categoryIds,
    this.limitPerCategory = 8,
    this.maxItems = 24,
  });

  final List<String> categoryIds;
  final int limitPerCategory;
  final int maxItems;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CategoryProductShelfRequest &&
            listEquals(categoryIds, other.categoryIds) &&
            limitPerCategory == other.limitPerCategory &&
            maxItems == other.maxItems;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(categoryIds),
        limitPerCategory,
        maxItems,
      );
}

final categoryProductShelfProvider = FutureProvider.autoDispose
    .family<List<ProductEntity>, CategoryProductShelfRequest>(
  (ref, request) async {
    // Per-shop price/stock — a shop switch must force a refetch, never
    // silently keep serving the previous store's products.
    ref.watch(storefrontScopeProvider);
    ref.cacheFor(const Duration(minutes: 5));
    final useCase = ref.read(getCategoryProductsUseCaseProvider);
    final orderedIds = request.categoryIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (orderedIds.isEmpty) {
      return const <ProductEntity>[];
    }

    final merged = <String, ProductEntity>{};
    String? failureMessage;
    var hasSuccess = false;

    for (final categoryId in orderedIds) {
      final result = await useCase.call(
        categoryId: categoryId,
        page: 1,
        limit: request.limitPerCategory,
      );

      result.fold(
        (failure) {
          failureMessage ??= failure.message;
        },
        (pageResult) {
          hasSuccess = true;
          for (final product in pageResult.items) {
            merged.putIfAbsent(product.id, () => product);
            if (merged.length >= request.maxItems) {
              break;
            }
          }
        },
      );

      if (merged.length >= request.maxItems) {
        break;
      }
    }

    if (!hasSuccess && failureMessage != null) {
      throw StateError(failureMessage!);
    }

    return merged.values.take(request.maxItems).toList(growable: false);
  },
);
