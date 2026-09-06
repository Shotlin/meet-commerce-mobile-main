import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/domain/entities/refund_request_status_entity.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/domain/repositories/refund_request_repository.dart';

class GetRefundRequestByOrderUseCase {
  const GetRefundRequestByOrderUseCase(this._repository);

  final RefundRequestRepository _repository;

  Future<Either<Failure, RefundRequestStatusEntity?>> call(String orderId) {
    return _repository.getByOrder(orderId);
  }
}
