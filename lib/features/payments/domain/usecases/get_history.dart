import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/repositories/payment_repository.dart';

class GetHistoryUseCase {
  const GetHistoryUseCase(this._repository);

  final PaymentRepository _repository;

  Future<Either<Failure, PaymentHistoryResult>> call({
    int page = 1,
    int limit = 10,
  }) {
    return _repository.getHistory(page: page, limit: limit);
  }
}
