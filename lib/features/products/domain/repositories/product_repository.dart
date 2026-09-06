import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

class ProductListResult {
  const ProductListResult({
    required this.items,
    required this.pagination,
    this.isStale = false,
  });

  final List<ProductEntity> items;
  final PaginationEntity pagination;
  final bool isStale;
}

abstract class ProductRepository {
  Future<Either<Failure, ProductListResult>> getProducts({
    int page = 1,
    int limit = 20,
  });

  Future<Either<Failure, ProductEntity>> getProductDetail(String productId);

  Future<Either<Failure, List<ProductEntity>>> getFeatured({
    int limit = 12,
  });

  Future<Either<Failure, List<ProductEntity>>> getNewArrivals({
    int limit = 12,
  });

  Future<Either<Failure, List<ProductEntity>>> getDeals({
    int limit = 12,
  });

  Future<Either<Failure, List<ProductEntity>>> getRelated(
    String productId, {
    int limit = 8,
  });

  Future<Either<Failure, List<ProductEntity>>> getPairWith(
    String productId, {
    int limit = 10,
  });
}
