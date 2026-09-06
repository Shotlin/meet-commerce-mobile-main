import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/entities/payment_entity.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/entities/razorpay_order_entity.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

class PaymentVerificationParams {
  const PaymentVerificationParams({
    required this.orderId,
    required this.razorpayOrderId,
    required this.paymentId,
    required this.signature,
  });

  final String orderId;
  final String razorpayOrderId;
  final String paymentId;
  final String signature;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'orderId': orderId,
      'paymentId': paymentId,
      'signature': signature,
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': paymentId,
      'razorpaySignature': signature,
    };
  }
}

class WalletTopupParams {
  const WalletTopupParams({
    required this.amount,
  });

  final double amount;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'amount': amount,
    };
  }
}

class WalletTopupVerificationParams {
  const WalletTopupVerificationParams({
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
    };
  }
}

class PaymentHistoryResult {
  const PaymentHistoryResult({
    required this.payments,
    required this.pagination,
  });

  final List<PaymentEntity> payments;
  final PaginationEntity pagination;
}

/// Current authoritative status of a Razorpay order, per the backend's
/// `payments` record — polled after the checkout SDK reports an ambiguous
/// result instead of assuming failure.
class PaymentStatusResult {
  const PaymentStatusResult({
    required this.status,
    this.errorCode,
    this.errorDescription,
    this.errorReason,
  });

  /// One of PENDING / PAID / FAILED / EXPIRED (mirrors the backend's
  /// `payments.status` column verbatim).
  final String status;
  final String? errorCode;
  final String? errorDescription;
  final String? errorReason;

  bool get isPaid => status == 'PAID';
  bool get isFailed => status == 'FAILED' || status == 'EXPIRED';

  /// The best available human-readable reason for a failure, preferring
  /// Razorpay's own `error_reason` over its longer `error_description`.
  String? get displayReason => errorReason ?? errorDescription;
}

abstract class PaymentRepository {
  Future<Either<Failure, RazorpayOrderEntity>> createPaymentOrder(
    String orderId,
  );

  Future<Either<Failure, PaymentEntity>> verifyPayment(
    PaymentVerificationParams params,
  );

  Future<Either<Failure, PaymentHistoryResult>> getHistory({
    int page = 1,
    int limit = 10,
  });

  Future<Either<Failure, PaymentStatusResult>> getPaymentStatus(
    String razorpayOrderId,
  );

  Future<Either<Failure, RazorpayOrderEntity>> createWalletTopup(
    WalletTopupParams params,
  );

  Future<Either<Failure, double>> verifyWalletTopup(
    WalletTopupVerificationParams params,
  );

  Future<Either<Failure, double>> getWalletBalance();

  Future<Either<Failure, double>> payFromWallet(String orderId);
}
