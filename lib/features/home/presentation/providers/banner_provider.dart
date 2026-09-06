import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/features/home/data/datasources/home_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/home/data/repositories/home_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/home/domain/entities/banner_entity.dart';
import 'package:bakaloo_flutter_app/features/home/domain/repositories/home_repository.dart';
import 'package:bakaloo_flutter_app/features/home/domain/usecases/get_banners_usecase.dart';
import 'package:bakaloo_flutter_app/features/home/domain/usecases/get_featured_products_usecase.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';

part 'banner_provider.g.dart';

final homeRemoteDataSourceProvider = Provider<HomeRemoteDataSource>((Ref ref) {
  return HomeRemoteDataSource(ref.watch(apiClientProvider));
});

final homeRepositoryProvider = Provider<HomeRepository>((Ref ref) {
  return HomeRepositoryImpl(ref.watch(homeRemoteDataSourceProvider));
});

final getBannersUseCaseProvider = Provider<GetBannersUseCase>((Ref ref) {
  return GetBannersUseCase(ref.watch(homeRepositoryProvider));
});

final getFeaturedProductsUseCaseProvider =
    Provider<GetFeaturedProductsUseCase>((Ref ref) {
  return GetFeaturedProductsUseCase(ref.watch(homeRepositoryProvider));
});

@riverpod
Future<List<BannerEntity>> banner(Ref ref) async {
  final result = await ref.read(getBannersUseCaseProvider).call();
  return result.fold((_) => const <BannerEntity>[], (data) => data);
}

/// Top-carousel banners for the mobile Category-landing page
/// (banner_type='category', admin-managed via Categories → Page Banners).
@riverpod
Future<List<BannerEntity>> categoryPageBanners(Ref ref) async {
  final result =
      await ref.read(getBannersUseCaseProvider).call(type: 'category');
  return result.fold((_) => const <BannerEntity>[], (data) => data);
}

/// Bottom combo-strip banner for the mobile Category-landing page
/// (banner_type='category_footer').
@riverpod
Future<List<BannerEntity>> categoryFooterBanners(Ref ref) async {
  final result =
      await ref.read(getBannersUseCaseProvider).call(type: 'category_footer');
  return result.fold((_) => const <BannerEntity>[], (data) => data);
}

@riverpod
Future<List<ProductEntity>> homeFeaturedProducts(Ref ref) async {
  final result = await ref.read(getFeaturedProductsUseCaseProvider).call(
        limit: 4,
      );
  return result.fold((_) => const <ProductEntity>[], (data) => data);
}
