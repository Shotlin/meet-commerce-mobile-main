import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/entities/razorpay_order_entity.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/entities/transaction_entity.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/entities/wallet_entity.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/entities/wallet_recipient_entity.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

class WalletTransactionsResult {
  const WalletTransactionsResult({
    required this.transactions,
    required this.pagination,
  });

  final List<TransactionEntity> transactions;
  final PaginationEntity pagination;
}

class WalletTopupVerifyParams {
  const WalletTopupVerifyParams({
    required this.paymentId,
    required this.orderId,
    required this.signature,
  });

  final String paymentId;
  final String orderId;
  final String signature;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'paymentId': paymentId,
      'orderId': orderId,
      'signature': signature,
      'razorpayPaymentId': paymentId,
      'razorpayOrderId': orderId,
      'razorpaySignature': signature,
    };
  }
}

class WalletTransferParams {
  const WalletTransferParams({
    required this.phone,
    required this.amount,
    this.description,
  });

  final String phone;
  final double amount;
  final String? description;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'phone': phone,
      'amount': amount,
      'description': description,
    }..removeWhere((key, value) => value == null || value == '');
  }
}

abstract class WalletRepository {
  Future<Either<Failure, WalletEntity>> getWallet();

  Future<Either<Failure, WalletTransactionsResult>> getTransactions({
    int page = 1,
    int limit = 20,
    WalletTransactionType? type,
  });

  Future<Either<Failure, RazorpayOrderEntity>> topup(double amount);

  Future<Either<Failure, WalletEntity>> topupVerify(
    WalletTopupVerifyParams params,
  );

  Future<Either<Failure, WalletEntity>> transfer(
    WalletTransferParams params,
  );

  Future<Either<Failure, List<WalletRecipientEntity>>> searchRecipient(
    String q,
  );
}
