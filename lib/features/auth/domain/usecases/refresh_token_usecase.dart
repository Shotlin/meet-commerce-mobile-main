import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/auth/domain/entities/user_entity.dart';
import 'package:bakaloo_flutter_app/features/auth/domain/repositories/auth_repository.dart';

class RefreshTokenUseCase {
  const RefreshTokenUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, TokenEntity>> call(String refreshToken) {
    return _repository.refreshToken(refreshToken: refreshToken);
  }
}
