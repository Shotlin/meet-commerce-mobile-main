import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/entities/transaction_entity.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/repositories/wallet_repository.dart';

class GetTransactionsUseCase {
  const GetTransactionsUseCase(this._repository);

  final WalletRepository _repository;

  Future<Either<Failure, WalletTransactionsResult>> call({
    int page = 1,
    int limit = 20,
    WalletTransactionType? type,
  }) {
    return _repository.getTransactions(
      page: page,
      limit: limit,
      type: type,
    );
  }
}
