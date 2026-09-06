import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/repositories/cart_repository.dart';

class UpdateItemUseCase {
  const UpdateItemUseCase(this._repository);

  final CartRepository _repository;

  Future<Either<Failure, CartEntity>> call({
    required String productId,
    required int quantity,
    String? shopProductId,
  }) {
    return _repository.updateItem(
      productId: productId,
      quantity: quantity,
      shopProductId: shopProductId,
    );
  }
}
