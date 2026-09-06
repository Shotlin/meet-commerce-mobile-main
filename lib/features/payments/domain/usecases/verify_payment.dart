import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/entities/payment_entity.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/repositories/payment_repository.dart';

class VerifyPaymentUseCase {
  const VerifyPaymentUseCase(this._repository);

  final PaymentRepository _repository;

  Future<Either<Failure, PaymentEntity>> call(
    PaymentVerificationParams params,
  ) {
    return _repository.verifyPayment(params);
  }
}
