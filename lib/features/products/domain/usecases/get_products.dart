import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/products/domain/repositories/product_repository.dart';

class GetProductsUseCase {
  const GetProductsUseCase(this._repository);

  final ProductRepository _repository;

  Future<Either<Failure, ProductListResult>> call({
    int page = 1,
    int limit = 20,
  }) {
    return _repository.getProducts(page: page, limit: limit);
  }
}
