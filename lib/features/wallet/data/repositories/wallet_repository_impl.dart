import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/entities/razorpay_order_entity.dart';
import 'package:bakaloo_flutter_app/features/wallet/data/datasources/wallet_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/entities/transaction_entity.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/entities/wallet_entity.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/entities/wallet_recipient_entity.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/repositories/wallet_repository.dart';

class WalletRepositoryImpl implements WalletRepository {
  const WalletRepositoryImpl({
    required WalletRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final WalletRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, WalletEntity>> getWallet() async {
    try {
      final wallet = await _remoteDataSource.getWallet();
      return Right(wallet.toEntity());
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load wallet balance right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, WalletTransactionsResult>> getTransactions({
    int page = 1,
    int limit = 20,
    WalletTransactionType? type,
  }) async {
    try {
      final result = await _remoteDataSource.getTransactions(
        page: page,
        limit: limit,
        type: type,
      );
      return Right(
        WalletTransactionsResult(
          transactions: result.transactions
              .map((transaction) => transaction.toEntity())
              .toList(growable: false),
          pagination: result.pagination,
        ),
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(
          message: 'Unable to load wallet transactions right now.',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, RazorpayOrderEntity>> topup(double amount) async {
    try {
      final result = await _remoteDataSource.topup(amount);
      return Right(result.toEntity());
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to start wallet top-up right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, WalletEntity>> topupVerify(
    WalletTopupVerifyParams params,
  ) async {
    try {
      final wallet = await _remoteDataSource.topupVerify(params);
      return Right(wallet.toEntity());
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to verify wallet top-up right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, WalletEntity>> transfer(
    WalletTransferParams params,
  ) async {
    try {
      final wallet = await _remoteDataSource.transfer(params);
      return Right(wallet.toEntity());
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to transfer money right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, List<WalletRecipientEntity>>> searchRecipient(
    String q,
  ) async {
    try {
      final results = await _remoteDataSource.searchRecipient(q);
      return Right(
        results
            .map((recipient) => recipient.toEntity())
            .toList(growable: false),
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to search for a recipient right now.'),
      );
    }
  }
}
