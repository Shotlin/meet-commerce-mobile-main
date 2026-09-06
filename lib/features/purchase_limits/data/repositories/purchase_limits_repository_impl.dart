import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/data/datasources/purchase_limits_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/domain/entities/purchase_limit_status_entity.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/domain/repositories/purchase_limits_repository.dart';

class PurchaseLimitsRepositoryImpl implements PurchaseLimitsRepository {
  const PurchaseLimitsRepositoryImpl({
    required PurchaseLimitsRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final PurchaseLimitsRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, List<PurchaseLimitStatusEntity>>> getStatus(
    List<String> productIds,
  ) async {
    try {
      final models = await _remoteDataSource.getStatus(productIds);
      return Right(models.map((model) => model.toEntity()).toList());
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(
          message: 'Unable to load purchase limits right now.',
        ),
      );
    }
  }
}
