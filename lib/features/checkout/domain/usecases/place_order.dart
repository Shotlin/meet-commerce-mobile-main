import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/repositories/checkout_repository.dart';

class PlaceOrderUseCase {
  const PlaceOrderUseCase(this._repository);

  final CheckoutRepository _repository;

  Future<Either<Failure, PlacedOrderEntity>> call(
    PlaceOrderParams params,
  ) {
    return _repository.placeOrder(params);
  }
}
