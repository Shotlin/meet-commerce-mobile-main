import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/categories/domain/repositories/category_repository.dart';
import 'package:bakaloo_flutter_app/features/products/domain/repositories/product_repository.dart';

class GetCategoryProductsUseCase {
  const GetCategoryProductsUseCase(this._repository);

  final CategoryRepository _repository;

  Future<Either<Failure, ProductListResult>> call({
    required String categoryId,
    int page = 1,
    int limit = 20,
  }) {
    return _repository.getCategoryProducts(
      categoryId: categoryId,
      page: page,
      limit: limit,
    );
  }
}
