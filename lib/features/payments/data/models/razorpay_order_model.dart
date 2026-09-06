import 'package:bakaloo_flutter_app/features/payments/domain/entities/razorpay_order_entity.dart';

class RazorpayOrderModel {
  const RazorpayOrderModel({
    required this.key,
    required this.amount,
    required this.razorpayOrderId,
    required this.orderId,
  });

  final String key;
  final int amount;
  final String razorpayOrderId;
  final String orderId;

  factory RazorpayOrderModel.fromJson(
    Map<String, dynamic> json, {
    required String orderId,
  }) {
    return RazorpayOrderModel(
      key: _readString(json, <String>['keyId', 'key']),
      amount: _toPaise(json['amount']),
      razorpayOrderId:
          _readString(json, <String>['razorpayOrderId', 'orderId']),
      orderId: orderId,
    );
  }

  RazorpayOrderEntity toEntity() {
    return RazorpayOrderEntity(
      key: key,
      amount: amount,
      razorpayOrderId: razorpayOrderId,
      orderId: orderId,
    );
  }

  static String _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  static int _toPaise(Object? value) {
    if (value is int) {
      return value > 10000 ? value : value * 100;
    }
    if (value is double) {
      return (value * 100).round();
    }
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return 0;
    }
    return (parsed * 100).round();
  }
}
