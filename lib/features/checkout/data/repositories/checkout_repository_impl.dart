import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/checkout/data/datasources/order_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/repositories/checkout_repository.dart';

class CheckoutRepositoryImpl implements CheckoutRepository {
  const CheckoutRepositoryImpl({
    required OrderRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final OrderRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, PlacedOrderEntity>> placeOrder(
    PlaceOrderParams params,
  ) async {
    try {
      final order = await _remoteDataSource.placeOrder(params.toJson());
      return Right(order.toEntity());
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to place the order right now.'),
      );
    }
  }
}
