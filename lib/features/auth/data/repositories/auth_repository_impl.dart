import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/core/storage/secure_storage_service.dart';
import 'package:bakaloo_flutter_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/auth/domain/entities/user_entity.dart';
import 'package:bakaloo_flutter_app/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required SecureStorageService secureStorageService,
  })  : _remoteDataSource = remoteDataSource,
        _secureStorageService = secureStorageService;

  final AuthRemoteDataSource _remoteDataSource;
  final SecureStorageService _secureStorageService;

  @override
  Future<Either<Failure, void>> sendOtp({required String phone}) async {
    try {
      await _remoteDataSource.sendOtp(phone: phone);
      return const Right(null);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to send OTP. Please try again.'),
      );
    }
  }

  @override
  Future<Either<Failure, AuthEntity>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final authResponse = await _remoteDataSource.verifyOtp(
        phone: phone,
        otp: otp,
      );

      await _secureStorageService.saveTokens(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
      );
      await _secureStorageService.saveUserId(authResponse.user.id);
      await HiveService.userBox.put('user', authResponse.user.toJson());

      return Right(authResponse.toEntity());
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to verify OTP. Please try again.'),
      );
    }
  }

  @override
  Future<Either<Failure, TokenEntity>> refreshToken({
    required String refreshToken,
  }) async {
    try {
      final tokenModel = await _remoteDataSource.refreshToken(
        refreshToken: refreshToken,
      );

      await _secureStorageService.saveTokens(
        accessToken: tokenModel.accessToken,
        refreshToken: tokenModel.refreshToken,
      );

      return Right(tokenModel.toEntity());
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to refresh your session.'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _remoteDataSource.logout();
      await _secureStorageService.clearAll();
      await HiveService.userBox.clear();
      return const Right(null);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to sign out right now.'),
      );
    }
  }
}
