import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/core/storage/cache_strategy.dart';
import 'package:bakaloo_flutter_app/features/categories/data/datasources/category_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/categories/data/local/category_local_datasource.dart';
import 'package:bakaloo_flutter_app/features/categories/domain/entities/category_entity.dart';
import 'package:bakaloo_flutter_app/features/categories/domain/repositories/category_repository.dart';
import 'package:bakaloo_flutter_app/features/products/data/models/product_model.dart';
import 'package:bakaloo_flutter_app/features/products/domain/repositories/product_repository.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  const CategoryRepositoryImpl({
    required CategoryRemoteDataSource remoteDataSource,
    required CategoryLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  final CategoryRemoteDataSource _remoteDataSource;
  final CategoryLocalDataSource _localDataSource;

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories() async {
    final cached = _sanitizeCategories(
      _localDataSource.getCategories()?.map(_mapCategory).toList() ??
          const <CategoryEntity>[],
    );
    final isFresh = _localDataSource.isFresh(
      'categories_all',
      CacheStrategy.categories.ttl!,
    );

    if (cached.isNotEmpty && isFresh) {
      unawaited(_refreshCategories());
      return Right(cached);
    }

    try {
      final categories =
          _sanitizeCategories(await _remoteDataSource.getCategories());
      await _localDataSource.cacheCategories(
        categories.map(_toCategoryJson).toList(),
      );
      return Right(categories);
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
        UnknownFailure(message: 'Unable to load categories right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, ProductListResult>> getCategoryProducts({
    required String categoryId,
    int page = 1,
    int limit = 20,
  }) async {
    final cacheKey = _localDataSource.productsCacheKey(categoryId);

    if (page == 1) {
      final cached = _cachedProducts(cacheKey);
      final isFresh = _localDataSource.isFresh(
        cacheKey,
        const Duration(minutes: 10),
      );

      if (cached != null && isFresh) {
        unawaited(_refreshCategoryProducts(categoryId, limit));
        return Right(cached);
      }

      try {
        final remotePage = await _remoteDataSource.getCategoryProducts(
          categoryId: categoryId,
          page: page,
          limit: limit,
        );
        await _localDataSource.cacheCategoryProducts(
          categoryId: categoryId,
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
          UnknownFailure(
            message: 'Unable to load category products right now.',
          ),
        );
      }
    }

    try {
      final remotePage = await _remoteDataSource.getCategoryProducts(
        categoryId: categoryId,
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
        UnknownFailure(message: 'Unable to load more category products.'),
      );
    }
  }

  Future<void> _refreshCategories() async {
    try {
      final categories =
          _sanitizeCategories(await _remoteDataSource.getCategories());
      await _localDataSource.cacheCategories(
        categories.map(_toCategoryJson).toList(),
      );
    } catch (_) {}
  }

  Future<void> _refreshCategoryProducts(String categoryId, int limit) async {
    try {
      final remotePage = await _remoteDataSource.getCategoryProducts(
        categoryId: categoryId,
        page: 1,
        limit: limit,
      );
      await _localDataSource.cacheCategoryProducts(
        categoryId: categoryId,
        items:
            remotePage.items.map((ProductModel item) => item.toJson()).toList(),
        pagination: remotePage.pagination,
      );
    } catch (_) {}
  }

  ProductListResult? _cachedProducts(String cacheKey) {
    final cached = _localDataSource.getCategoryProducts(
      cacheKey.replaceFirst('category_products_', ''),
    );
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
    final pagination = cached['pagination'] is Map
        ? PaginationEntity.fromJson(
            Map<String, dynamic>.from(cached['pagination'] as Map),
          )
        : const PaginationEntity(page: 1, limit: 20, total: 0, totalPages: 0);

    return ProductListResult(items: items, pagination: pagination);
  }

  CategoryEntity _mapCategory(Map<String, dynamic> json) {
    return CategoryEntity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      imageUrl: ApiConstants.resolveMediaUrl(json['image_url']?.toString()),
      parentId: json['parent_id']?.toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      productCount: (json['product_count'] as num?)?.toInt() ?? 0,
      categoryType: json['category_type']?.toString() ?? 'STANDARD',
    );
  }

  Map<String, dynamic> _toCategoryJson(CategoryEntity category) {
    return <String, dynamic>{
      'id': category.id,
      'name': category.name,
      'description': category.description,
      'image_url': category.imageUrl,
      'parent_id': category.parentId,
      'sort_order': category.sortOrder,
      'is_active': category.isActive,
      'product_count': category.productCount,
      'category_type': category.categoryType,
    };
  }

  /// BUNDLE categories are promo-only groupings reachable only via a
  /// banner deep-link — they must never appear in normal category
  /// browsing (list screens, home strip), so they're filtered out here
  /// alongside the existing isActive check.
  List<CategoryEntity> _sanitizeCategories(List<CategoryEntity> categories) {
    final sanitized = categories
        .where((category) => category.isActive && !category.isBundle)
        .toList()
      ..sort((a, b) {
        final sortOrder = a.sortOrder.compareTo(b.sortOrder);
        if (sortOrder != 0) {
          return sortOrder;
        }
        return a.name.compareTo(b.name);
      });
    return sanitized;
  }
}
