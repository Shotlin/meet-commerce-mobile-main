import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_entity.freezed.dart';

@freezed
abstract class PaymentEntity with _$PaymentEntity {
  const factory PaymentEntity({
    required String id,
    required String orderId,
    required double amount,
    required String currency,
    required String status,
    required DateTime createdAt,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    String? method,
  }) = _PaymentEntity;
}
