import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/categories/domain/entities/category_entity.dart';
import 'package:bakaloo_flutter_app/features/products/domain/repositories/product_repository.dart';

abstract class CategoryRepository {
  Future<Either<Failure, List<CategoryEntity>>> getCategories();

  Future<Either<Failure, ProductListResult>> getCategoryProducts({
    required String categoryId,
    int page = 1,
    int limit = 20,
  });
}
