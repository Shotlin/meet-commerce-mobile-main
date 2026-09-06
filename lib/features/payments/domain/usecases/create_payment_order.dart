import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/entities/razorpay_order_entity.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/repositories/payment_repository.dart';

class CreatePaymentOrderUseCase {
  const CreatePaymentOrderUseCase(this._repository);

  final PaymentRepository _repository;

  Future<Either<Failure, RazorpayOrderEntity>> call(String orderId) {
    return _repository.createPaymentOrder(orderId);
  }
}
