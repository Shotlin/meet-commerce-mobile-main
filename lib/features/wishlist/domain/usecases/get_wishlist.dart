import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/wishlist/domain/entities/wishlist_entity.dart';
import 'package:bakaloo_flutter_app/features/wishlist/domain/repositories/wishlist_repository.dart';

class GetWishlistUseCase {
  const GetWishlistUseCase(this._repository);

  final WishlistRepository _repository;

  Future<Either<Failure, WishlistEntity>> call() {
    return _repository.getWishlist();
  }
}
