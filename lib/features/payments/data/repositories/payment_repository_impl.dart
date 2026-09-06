import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/entities/payment_entity.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/entities/razorpay_order_entity.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/repositories/payment_repository.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  const PaymentRepositoryImpl({
    required PaymentRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final PaymentRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, RazorpayOrderEntity>> createPaymentOrder(
    String orderId,
  ) async {
    try {
      final order = await _remoteDataSource.createPaymentOrder(orderId);
      return Right(order.toEntity());
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to start the payment right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, PaymentEntity>> verifyPayment(
    PaymentVerificationParams params,
  ) async {
    try {
      final payment = await _remoteDataSource.verifyPayment(params);
      return Right(payment.toEntity());
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to verify the payment right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, PaymentHistoryResult>> getHistory({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final history = await _remoteDataSource.getHistory(
        page: page,
        limit: limit,
      );
      return Right(
        PaymentHistoryResult(
          payments: history.payments
              .map((payment) => payment.toEntity())
              .toList(growable: false),
          pagination: history.pagination,
        ),
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load payment history right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, PaymentStatusResult>> getPaymentStatus(
    String razorpayOrderId,
  ) async {
    try {
      final status = await _remoteDataSource.getPaymentStatus(razorpayOrderId);
      return Right(
        PaymentStatusResult(
          status: status.status,
          errorCode: status.errorCode,
          errorDescription: status.errorDescription,
          errorReason: status.errorReason,
        ),
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to check payment status right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, RazorpayOrderEntity>> createWalletTopup(
    WalletTopupParams params,
  ) async {
    try {
      final order = await _remoteDataSource.createWalletTopup(params);
      return Right(order.toEntity());
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to start the wallet top-up right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, double>> verifyWalletTopup(
    WalletTopupVerificationParams params,
  ) async {
    try {
      final balance = await _remoteDataSource.verifyWalletTopup(params);
      return Right(balance);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(
          message: 'Unable to verify the wallet top-up right now.',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, double>> getWalletBalance() async {
    try {
      final balance = await _remoteDataSource.getWalletBalance();
      return Right(balance);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(
          message: 'Unable to load the wallet balance right now.',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, double>> payFromWallet(String orderId) async {
    try {
      final balance = await _remoteDataSource.payFromWallet(orderId);
      return Right(balance);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(
          message: 'Unable to complete the wallet payment right now.',
        ),
      );
    }
  }
}
