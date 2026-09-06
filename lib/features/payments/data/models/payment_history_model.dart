import 'package:bakaloo_flutter_app/features/payments/domain/entities/payment_entity.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

class PaymentHistoryModel {
  const PaymentHistoryModel({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.method,
  });

  final String id;
  final String orderId;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final double amount;
  final String currency;
  final String status;
  final String? method;
  final DateTime createdAt;

  factory PaymentHistoryModel.fromJson(Map<String, dynamic> json) {
    return PaymentHistoryModel(
      id: _readString(json, <String>['id']),
      orderId: _readString(json, <String>['orderId', 'order_id']),
      razorpayOrderId: _readNullableString(
        json,
        <String>['razorpayOrderId', 'razorpay_order_id'],
      ),
      razorpayPaymentId: _readNullableString(
        json,
        <String>['razorpayPaymentId', 'razorpay_payment_id'],
      ),
      amount: _toDouble(json['amount']),
      currency: _readString(json, <String>['currency'], fallback: 'INR'),
      status: _readString(json, <String>['status'], fallback: 'PENDING'),
      method: _readNullableString(json, <String>['method']),
      createdAt: _readDateTime(json, <String>['createdAt', 'created_at']) ??
          DateTime.now(),
    );
  }

  PaymentEntity toEntity() {
    return PaymentEntity(
      id: id,
      orderId: orderId,
      razorpayOrderId: razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId,
      amount: amount,
      currency: currency,
      status: status,
      method: method,
      createdAt: createdAt,
    );
  }

  static String _readString(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return fallback;
  }

  static String? _readNullableString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static double _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _readDateTime(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return DateTime.tryParse(value.trim());
      }
    }
    return null;
  }
}

class PaymentHistoryPageModel {
  const PaymentHistoryPageModel({
    required this.payments,
    required this.pagination,
  });

  final List<PaymentHistoryModel> payments;
  final PaginationEntity pagination;
}
