import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/domain/repositories/product_repository.dart';

class GetNewArrivalsUseCase {
  const GetNewArrivalsUseCase(this._repository);

  final ProductRepository _repository;

  Future<Either<Failure, List<ProductEntity>>> call({int limit = 12}) {
    return _repository.getNewArrivals(limit: limit);
  }
}
