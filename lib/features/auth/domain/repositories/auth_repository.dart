import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/auth/domain/entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, void>> sendOtp({required String phone});

  Future<Either<Failure, AuthEntity>> verifyOtp({
    required String phone,
    required String otp,
  });

  Future<Either<Failure, TokenEntity>> refreshToken({
    required String refreshToken,
  });

  Future<Either<Failure, void>> logout();
}
