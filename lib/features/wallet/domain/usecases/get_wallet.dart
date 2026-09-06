import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/entities/wallet_entity.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/repositories/wallet_repository.dart';

class GetWalletUseCase {
  const GetWalletUseCase(this._repository);

  final WalletRepository _repository;

  Future<Either<Failure, WalletEntity>> call() {
    return _repository.getWallet();
  }
}
