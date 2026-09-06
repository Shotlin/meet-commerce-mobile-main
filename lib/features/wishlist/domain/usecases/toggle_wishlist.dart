import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/wishlist/domain/entities/wishlist_entity.dart';
import 'package:bakaloo_flutter_app/features/wishlist/domain/repositories/wishlist_repository.dart';

class ToggleWishlistUseCase {
  const ToggleWishlistUseCase(this._repository);

  final WishlistRepository _repository;

  Future<Either<Failure, WishlistEntity>> call(
    String productId, {
    required bool isInWishlist,
  }) {
    return _repository.toggleWishlist(
      productId,
      isInWishlist: isInWishlist,
    );
  }
}
