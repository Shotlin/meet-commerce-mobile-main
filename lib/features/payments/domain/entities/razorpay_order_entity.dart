import 'package:freezed_annotation/freezed_annotation.dart';

part 'razorpay_order_entity.freezed.dart';

@freezed
abstract class RazorpayOrderEntity with _$RazorpayOrderEntity {
  const factory RazorpayOrderEntity({
    required String key,
    required int amount,
    required String razorpayOrderId,
    required String orderId,
  }) = _RazorpayOrderEntity;
}
