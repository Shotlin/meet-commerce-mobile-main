import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/domain/repositories/product_repository.dart';

class GetPairWithUseCase {
  const GetPairWithUseCase(this._repository);

  final ProductRepository _repository;

  Future<Either<Failure, List<ProductEntity>>> call(
    String productId, {
    int limit = 10,
  }) {
    return _repository.getPairWith(productId, limit: limit);
  }
}
