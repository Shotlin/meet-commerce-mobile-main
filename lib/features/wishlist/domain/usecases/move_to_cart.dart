import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/wishlist/domain/repositories/wishlist_repository.dart';

class MoveToCartUseCase {
  const MoveToCartUseCase(this._repository);

  final WishlistRepository _repository;

  Future<Either<Failure, int>> call() {
    return _repository.moveToCart();
  }
}
