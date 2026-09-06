import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_entity.dart';

class CartValidationResult {
  const CartValidationResult({
    required this.valid,
    required this.cart,
    this.warnings = const <String>[],
  });

  final bool valid;
  final CartEntity cart;
  final List<String> warnings;
}

abstract class CartRepository {
  Future<Either<Failure, CartEntity>> getCart();

  Future<Either<Failure, CartEntity>> addToCart({
    required String productId,
    required int quantity,
    String? shopProductId,
  });

  Future<Either<Failure, CartEntity>> updateItem({
    required String productId,
    required int quantity,
    String? shopProductId,
  });

  Future<Either<Failure, CartEntity>> removeItem(
    String productId, {
    String? shopProductId,
  });

  Future<Either<Failure, void>> clearCart();

  Future<Either<Failure, CartValidationResult>> validateCart();
}
