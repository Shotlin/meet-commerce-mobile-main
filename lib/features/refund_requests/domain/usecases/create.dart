import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/domain/repositories/refund_request_repository.dart';

class CreateRefundRequestUseCase {
  const CreateRefundRequestUseCase(this._repository);

  final RefundRequestRepository _repository;

  Future<Either<Failure, void>> call(RefundRequestCreateParams params) {
    return _repository.createRequest(params);
  }
}
