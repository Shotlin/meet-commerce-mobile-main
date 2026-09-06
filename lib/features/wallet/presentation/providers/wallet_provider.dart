import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/entities/razorpay_order_entity.dart';
import 'package:bakaloo_flutter_app/features/payments/presentation/providers/payment_provider.dart';
import 'package:bakaloo_flutter_app/features/wallet/data/datasources/wallet_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/entities/transaction_entity.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/entities/wallet_entity.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/usecases/get_transactions.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/usecases/get_wallet.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/usecases/search_recipient.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/usecases/topup.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/usecases/topup_verify.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/usecases/transfer.dart';

part 'wallet_provider.g.dart';

enum WalletTransactionFilter {
  all,
  credit,
  debit,
}

extension WalletTransactionFilterX on WalletTransactionFilter {
  String get label => switch (this) {
        WalletTransactionFilter.all => 'All',
        WalletTransactionFilter.credit => 'Credit',
        WalletTransactionFilter.debit => 'Debit',
      };

  WalletTransactionType? get type => switch (this) {
        WalletTransactionFilter.all => null,
        WalletTransactionFilter.credit => WalletTransactionType.CREDIT,
        WalletTransactionFilter.debit => WalletTransactionType.DEBIT,
      };
}

class WalletActionResult {
  const WalletActionResult({
    this.failure,
  });

  final Failure? failure;

  bool get isSuccess => failure == null;
}

class WalletTopupOrderResult extends WalletActionResult {
  const WalletTopupOrderResult({
    super.failure,
    this.order,
  });

  final RazorpayOrderEntity? order;
}

final walletRemoteDataSourceProvider = Provider<WalletRemoteDataSource>((
  Ref ref,
) {
  return WalletRemoteDataSource(ref.watch(apiClientProvider));
});

final walletRepositoryProvider = Provider<WalletRepository>((Ref ref) {
  return WalletRepositoryImpl(
    remoteDataSource: ref.watch(walletRemoteDataSourceProvider),
  );
});

final getWalletUseCaseProvider = Provider<GetWalletUseCase>((Ref ref) {
  return GetWalletUseCase(ref.watch(walletRepositoryProvider));
});

final getWalletTransactionsUseCaseProvider =
    Provider<GetTransactionsUseCase>((Ref ref) {
  return GetTransactionsUseCase(ref.watch(walletRepositoryProvider));
});

final walletTopupUseCaseProvider = Provider<TopupUseCase>((Ref ref) {
  return TopupUseCase(ref.watch(walletRepositoryProvider));
});

final walletTopupVerifyUseCaseProvider =
    Provider<TopupVerifyUseCase>((Ref ref) {
  return TopupVerifyUseCase(ref.watch(walletRepositoryProvider));
});

final walletTransferUseCaseProvider = Provider<TransferUseCase>((Ref ref) {
  return TransferUseCase(ref.watch(walletRepositoryProvider));
});

final searchRecipientUseCaseProvider =
    Provider<SearchRecipientUseCase>((Ref ref) {
  return SearchRecipientUseCase(ref.watch(walletRepositoryProvider));
});

@Riverpod(keepAlive: true)
class WalletNotifier extends _$WalletNotifier {
  @override
  Future<WalletEntity> build() async {
    final result = await ref.read(getWalletUseCaseProvider).call();
    return result.fold(
      (failure) => throw StateError(failure.message),
      (wallet) => wallet,
    );
  }

  Future<WalletActionResult> refreshWallet() async {
    final result = await ref.read(getWalletUseCaseProvider).call();
    return result.fold(
      (failure) => WalletActionResult(failure: failure),
      (wallet) {
        state = AsyncData(wallet);
        return const WalletActionResult();
      },
    );
  }

  Future<Either<Failure, WalletTransactionsResult>> getTransactionsPage({
    required int page,
    int limit = 20,
    WalletTransactionFilter filter = WalletTransactionFilter.all,
  }) {
    return ref.read(getWalletTransactionsUseCaseProvider).call(
          page: page,
          limit: limit,
          type: filter.type,
        );
  }

  Future<WalletTopupOrderResult> createTopupOrder(double amount) async {
    final normalizedAmount = amount.isFinite ? amount : 0.0;
    if (normalizedAmount <= 0) {
      return const WalletTopupOrderResult(
        failure: ValidationFailure(message: 'Enter a valid amount.'),
      );
    }

    final result =
        await ref.read(walletTopupUseCaseProvider).call(normalizedAmount);
    return result.fold(
      (failure) => WalletTopupOrderResult(failure: failure),
      (order) => WalletTopupOrderResult(order: order),
    );
  }

  Future<WalletActionResult> verifyTopup(
    WalletTopupVerifyParams params,
  ) async {
    final result =
        await ref.read(walletTopupVerifyUseCaseProvider).call(params);
    return result.fold(
      (failure) => WalletActionResult(failure: failure),
      (wallet) {
        state = AsyncData(wallet);
        ref.invalidate(walletBalanceProvider);
        return const WalletActionResult();
      },
    );
  }

  Future<WalletActionResult> transfer(
    WalletTransferParams params,
  ) async {
    final result = await ref.read(walletTransferUseCaseProvider).call(params);
    return result.fold(
      (failure) => WalletActionResult(failure: failure),
      (wallet) {
        state = AsyncData(wallet);
        ref.invalidate(walletBalanceProvider);
        return const WalletActionResult();
      },
    );
  }
}
