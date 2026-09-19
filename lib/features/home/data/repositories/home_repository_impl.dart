import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';
import 'package:bakaloo_flutter_app/features/home/data/datasources/home_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/home/data/models/banner_model.dart';
import 'package:bakaloo_flutter_app/features/home/domain/entities/banner_entity.dart';
import 'package:bakaloo_flutter_app/features/home/domain/repositories/home_repository.dart';
import 'package:bakaloo_flutter_app/features/products/data/models/product_model.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';

class HomeRepositoryImpl implements HomeRepository {
  const HomeRepositoryImpl(this._remoteDataSource);

  final HomeRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, List<BannerEntity>>> getBanners({String? type}) async {
    final cacheKey = type == null
        ? StorageKeys.cacheBanners
        : '${StorageKeys.cacheBanners}_$type';
    final cached = _readBannerCache(cacheKey);
    try {
      final banners = await _remoteDataSource.getBanners(type: type);
      await HiveService.bannersBox.put(
        cacheKey,
        banners.map((BannerModel banner) => banner.toJson()).toList(),
      );
      await HiveService.markCached(cacheKey);
      return Right(
        banners.map((BannerModel banner) => banner.toEntity()).toList(),
      );
    } on DioException catch (error) {
      if (cached.isNotEmpty) {
        return Right(cached);
      }
      return Left(handleDioError(error));
    } catch (_) {
      if (cached.isNotEmpty) {
        return Right(cached);
      }
      return const Left(
        UnknownFailure(message: 'Unable to load home banners right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> getFeaturedProducts({
    int limit = 12,
  }) async {
    final cacheKey = '${StorageKeys.cacheFeatured}_$limit';
    final cached = _readFeaturedCache(cacheKey);
    try {
      final products =
          await _remoteDataSource.getFeaturedProducts(limit: limit);
      await HiveService.productsBox.put(
        cacheKey,
        products.map((ProductModel product) => product.toJson()).toList(),
      );
      await HiveService.markCached(cacheKey);
      return Right(
        products.map((ProductModel product) => product.toEntity()).toList(),
      );
    } on DioException catch (error) {
      if (cached.isNotEmpty) {
        return Right(cached);
      }
      return Left(handleDioError(error));
    } catch (_) {
      if (cached.isNotEmpty) {
        return Right(cached);
      }
      return const Left(
        UnknownFailure(message: 'Unable to load featured products right now.'),
      );
    }
  }

  List<BannerEntity> _readBannerCache(String cacheKey) {
    final value = HiveService.bannersBox.get(cacheKey);
    if (value is! List) {
      return const <BannerEntity>[];
    }

    return value
        .whereType<Map>()
        .map(
          (Map item) => BannerModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .map((BannerModel banner) => banner.toEntity())
        .toList();
  }

  List<ProductEntity> _readFeaturedCache(String cacheKey) {
    final value = HiveService.productsBox.get(cacheKey);
    if (value is! List) {
      return const <ProductEntity>[];
    }

    return value
        .whereType<Map>()
        .map(
          (Map item) => ProductModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .map((ProductModel product) => product.toEntity())
        .toList();
  }
}
