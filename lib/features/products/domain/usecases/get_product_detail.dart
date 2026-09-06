import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/domain/repositories/product_repository.dart';

class GetProductDetailUseCase {
  const GetProductDetailUseCase(this._repository);

  final ProductRepository _repository;

  Future<Either<Failure, ProductEntity>> call(String productId) {
    return _repository.getProductDetail(productId);
  }
}
