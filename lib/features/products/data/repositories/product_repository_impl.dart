import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/core/storage/cache_strategy.dart';
import 'package:bakaloo_flutter_app/features/products/data/datasources/product_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/products/data/local/product_local_datasource.dart';
import 'package:bakaloo_flutter_app/features/products/data/models/product_model.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/domain/repositories/product_repository.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

class ProductRepositoryImpl implements ProductRepository {
  const ProductRepositoryImpl({
    required ProductRemoteDataSource remoteDataSource,
    required ProductLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  final ProductRemoteDataSource _remoteDataSource;
  final ProductLocalDataSource _localDataSource;
  static const Duration _pageCacheTtl = Duration(minutes: 10);

  @override
  Future<Either<Failure, ProductListResult>> getProducts({
    int page = 1,
    int limit = 20,
  }) async {
    final cacheKey = 'products_page_${page}_$limit';

    if (page == 1) {
      final cached = _cachedPage(cacheKey);
      final isFresh = _localDataSource.isFresh(cacheKey, _pageCacheTtl);
      if (cached != null && isFresh) {
        unawaited(_refreshPage1(cacheKey, limit));
        return Right(cached);
      }

      try {
        final remotePage = await _remoteDataSource.getProducts(
          page: page,
          limit: limit,
        );
        await _localDataSource.cacheList(
          key: cacheKey,
          items: remotePage.items
              .map((ProductModel item) => item.toJson())
              .toList(),
          pagination: remotePage.pagination,
        );
        return Right(
          ProductListResult(
            items: remotePage.items
                .map((ProductModel item) => item.toEntity())
                .toList(),
            pagination: remotePage.pagination,
          ),
        );
      } on DioException catch (error) {
        if (cached != null) {
          return Right(
            ProductListResult(
              items: cached.items,
              pagination: cached.pagination,
              isStale: true,
            ),
          );
        }
        return Left(handleDioError(error));
      } catch (_) {
        if (cached != null) {
          return Right(
            ProductListResult(
              items: cached.items,
              pagination: cached.pagination,
              isStale: true,
            ),
          );
        }
        return const Left(
          UnknownFailure(message: 'Unable to load products right now.'),
        );
      }
    }

    try {
      final remotePage = await _remoteDataSource.getProducts(
        page: page,
        limit: limit,
      );
      return Right(
        ProductListResult(
          items: remotePage.items
              .map((ProductModel item) => item.toEntity())
              .toList(),
          pagination: remotePage.pagination,
        ),
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load more products right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, ProductEntity>> getProductDetail(
    String productId,
  ) async {
    // Network-first: admin-controlled fields (return policy, price, stock)
    // need to show what's live right now, not what was cached on a
    // previous visit. The cache is a fallback for offline/error only —
    // serving it whenever it happened to still be "fresh" meant every
    // check right after a dashboard edit showed the pre-edit value, one
    // visit behind, since the fix only landed in the cache for next time.
    final cachedJson = _localDataSource.getCachedProduct(productId);
    final cachedEntity = cachedJson == null
        ? null
        : ProductModel.fromJson(cachedJson).toEntity();

    try {
      final remoteProduct = await _remoteDataSource.getProductDetail(productId);
      await _localDataSource.cacheProduct(
        productId: productId,
        product: remoteProduct.toJson(),
      );
      return Right(remoteProduct.toEntity());
    } on DioException catch (error) {
      if (cachedEntity != null) {
        return Right(cachedEntity);
      }
      return Left(handleDioError(error));
    } catch (_) {
      if (cachedEntity != null) {
        return Right(cachedEntity);
      }
      return const Left(
        UnknownFailure(message: 'Unable to load product details right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> getFeatured({int limit = 12}) {
    return _getSimpleList(
      () => _remoteDataSource.getFeatured(limit: limit),
      cacheKey: 'products_featured_$limit',
      ttl: CacheStrategy.featuredProducts.ttl!,
    );
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> getNewArrivals({
    int limit = 12,
  }) {
    return _getSimpleList(
      () => _remoteDataSource.getNewArrivals(limit: limit),
      cacheKey: 'products_new_arrivals_$limit',
      ttl: const Duration(minutes: 10),
    );
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> getDeals({int limit = 12}) {
    return _getSimpleList(
      () => _remoteDataSource.getDeals(limit: limit),
      cacheKey: 'products_deals_$limit',
      ttl: const Duration(minutes: 10),
    );
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> getRelated(
    String productId, {
    int limit = 8,
  }) async {
    try {
      final products =
          await _remoteDataSource.getRelated(productId, limit: limit);
      return Right(
        products.map((ProductModel item) => item.toEntity()).toList(),
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load related products right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, List<ProductEntity>>> getPairWith(
    String productId, {
    int limit = 10,
  }) async {
    try {
      final products =
          await _remoteDataSource.getPairWith(productId, limit: limit);
      return Right(
        products.map((ProductModel item) => item.toEntity()).toList(),
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load pair-with products right now.'),
      );
    }
  }

  ProductListResult? _cachedPage(String cacheKey) {
    final cached = _localDataSource.getCachedList(cacheKey);
    if (cached == null) {
      return null;
    }

    final items = (cached['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (Map item) => ProductModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .map((ProductModel item) => item.toEntity())
        .toList();
    final pagination = cached['pagination'] is Map<String, dynamic>
        ? PaginationEntity.fromJson(
            cached['pagination'] as Map<String, dynamic>,
          )
        : const PaginationEntity(page: 1, limit: 20, total: 0, totalPages: 0);

    return ProductListResult(items: items, pagination: pagination);
  }

  Future<void> _refreshPage1(String cacheKey, int limit) async {
    try {
      final remotePage =
          await _remoteDataSource.getProducts(page: 1, limit: limit);
      await _localDataSource.cacheList(
        key: cacheKey,
        items:
            remotePage.items.map((ProductModel item) => item.toJson()).toList(),
        pagination: remotePage.pagination,
      );
    } catch (_) {}
  }

  Future<Either<Failure, List<ProductEntity>>> _getSimpleList(
    Future<List<ProductModel>> Function() loader, {
    required String cacheKey,
    required Duration ttl,
  }) async {
    final cachedJson = _localDataSource.getCachedList(cacheKey);
    final cachedItems =
        (cachedJson?['items'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (Map item) =>
                  ProductModel.fromJson(Map<String, dynamic>.from(item)),
            )
            .map((ProductModel item) => item.toEntity())
            .toList();
    final isFresh = _localDataSource.isFresh(cacheKey, ttl);

    if (cachedItems.isNotEmpty && isFresh) {
      unawaited(_refreshSimpleList(loader, cacheKey));
      return Right(cachedItems);
    }

    try {
      final products = await loader();
      await _localDataSource.cacheList(
        key: cacheKey,
        items: products.map((ProductModel item) => item.toJson()).toList(),
        pagination: PaginationEntity(
          page: 1,
          limit: products.length,
          total: products.length,
          totalPages: products.isEmpty ? 0 : 1,
        ),
      );
      return Right(
        products.map((ProductModel item) => item.toEntity()).toList(),
      );
    } on DioException catch (error) {
      if (cachedItems.isNotEmpty) {
        return Right(cachedItems);
      }
      return Left(handleDioError(error));
    } catch (_) {
      if (cachedItems.isNotEmpty) {
        return Right(cachedItems);
      }
      return const Left(
        UnknownFailure(message: 'Unable to load products right now.'),
      );
    }
  }

  Future<void> _refreshSimpleList(
    Future<List<ProductModel>> Function() loader,
    String cacheKey,
  ) async {
    try {
      final products = await loader();
      await _localDataSource.cacheList(
        key: cacheKey,
        items: products.map((ProductModel item) => item.toJson()).toList(),
        pagination: PaginationEntity(
          page: 1,
          limit: products.length,
          total: products.length,
          totalPages: products.isEmpty ? 0 : 1,
        ),
      );
    } catch (_) {}
  }
}
