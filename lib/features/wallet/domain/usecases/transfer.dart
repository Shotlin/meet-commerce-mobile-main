import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/entities/wallet_entity.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/repositories/wallet_repository.dart';

class TransferUseCase {
  const TransferUseCase(this._repository);

  final WalletRepository _repository;

  Future<Either<Failure, WalletEntity>> call(WalletTransferParams params) {
    return _repository.transfer(params);
  }
}
