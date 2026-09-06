import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/repositories/cart_repository.dart';

class ClearCartUseCase {
  const ClearCartUseCase(this._repository);

  final CartRepository _repository;

  Future<Either<Failure, void>> call() {
    return _repository.clearCart();
  }
}
