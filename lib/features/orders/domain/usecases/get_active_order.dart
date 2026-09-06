import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/repositories/order_repository.dart';

class GetActiveOrderUseCase {
  const GetActiveOrderUseCase(this._repository);

  final OrderRepository _repository;

  Future<Either<Failure, OrderEntity?>> call() {
    return _repository.getActiveOrder();
  }
}
