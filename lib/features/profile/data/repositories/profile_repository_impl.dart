import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/profile/data/datasources/user_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/profile/domain/entities/user_stats_entity.dart';
import 'package:bakaloo_flutter_app/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl({
    required UserRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final UserRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, ProfileData>> getProfile() async {
    try {
      final profile = await _remoteDataSource.getProfile();
      return Right(
        ProfileData(
          user: profile.toEntity(),
          birthday: profile.birthday,
        ),
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load your profile right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, ProfileData>> updateProfile(
    UpdateProfileParams params,
  ) async {
    try {
      final profile = await _remoteDataSource.updateProfile(params);
      return Right(
        ProfileData(
          user: profile.toEntity(),
          birthday: profile.birthday,
        ),
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to update your profile right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, String>> uploadAvatar(File imageFile) async {
    try {
      final avatarUrl = await _remoteDataSource.uploadAvatar(imageFile);
      return Right(avatarUrl);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to upload avatar right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, UserStatsEntity>> getStats() async {
    try {
      final stats = await _remoteDataSource.getStats();
      return Right(stats.toEntity());
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load stats right now.'),
      );
    }
  }
}
