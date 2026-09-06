import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/repositories/order_repository.dart';

class ReorderUseCase {
  const ReorderUseCase(this._repository);

  final OrderRepository _repository;

  Future<Either<Failure, ReorderResult>> call(String orderId) {
    return _repository.reorder(orderId);
  }
}
