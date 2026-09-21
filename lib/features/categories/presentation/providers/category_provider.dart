import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/refresh/storefront_refresh_provider.dart';
import 'package:bakaloo_flutter_app/core/storefront/storefront_scope.dart';
import 'package:bakaloo_flutter_app/features/categories/data/datasources/category_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/categories/data/local/category_local_datasource.dart';
import 'package:bakaloo_flutter_app/features/categories/data/repositories/category_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/categories/domain/entities/category_entity.dart';
import 'package:bakaloo_flutter_app/features/categories/domain/repositories/category_repository.dart';
import 'package:bakaloo_flutter_app/features/categories/domain/usecases/get_categories.dart';
import 'package:bakaloo_flutter_app/features/categories/domain/usecases/get_category_products.dart';

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
  ref.watch(storefrontRefreshEpochProvider);
  ref.watch(storefrontScopeProvider);
  final result = await ref.read(getCategoriesUseCaseProvider).call();
  return result.fold((_) => const <CategoryEntity>[], (data) => data);
}
