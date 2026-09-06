import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/repositories/cart_repository.dart';

class ValidateCartUseCase {
  const ValidateCartUseCase(this._repository);

  final CartRepository _repository;

  Future<Either<Failure, CartValidationResult>> call() {
    return _repository.validateCart();
  }
}
