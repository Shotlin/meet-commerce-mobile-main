import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/data/datasources/refund_request_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/domain/entities/refund_request_status_entity.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/domain/repositories/refund_request_repository.dart';

class RefundRequestRepositoryImpl implements RefundRequestRepository {
  const RefundRequestRepositoryImpl({
    required RefundRequestRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final RefundRequestRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, void>> createRequest(
    RefundRequestCreateParams params,
  ) async {
    try {
      await _remoteDataSource.createRequest(params.toJson());
      return const Right(null);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to submit refund request right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, RefundRequestStatusEntity?>> getByOrder(
    String orderId,
  ) async {
    try {
      final status = await _remoteDataSource.getByOrder(orderId);
      return Right(status);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load refund request status right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> cancelRequest(String requestId) async {
    try {
      await _remoteDataSource.cancelRequest(requestId);
      return const Right(null);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to cancel refund request right now.'),
      );
    }
  }
}
