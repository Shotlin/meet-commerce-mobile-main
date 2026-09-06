import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/entities/razorpay_order_entity.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/repositories/wallet_repository.dart';

class TopupUseCase {
  const TopupUseCase(this._repository);

  final WalletRepository _repository;

  Future<Either<Failure, RazorpayOrderEntity>> call(double amount) {
    return _repository.topup(amount);
  }
}
