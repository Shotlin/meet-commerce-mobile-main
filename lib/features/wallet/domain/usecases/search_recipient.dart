import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/entities/wallet_recipient_entity.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/repositories/wallet_repository.dart';

class SearchRecipientUseCase {
  const SearchRecipientUseCase(this._repository);

  final WalletRepository _repository;

  Future<Either<Failure, List<WalletRecipientEntity>>> call(String q) {
    return _repository.searchRecipient(q);
  }
}
