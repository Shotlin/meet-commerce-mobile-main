import 'package:freezed_annotation/freezed_annotation.dart';

part 'checkout_summary_entity.freezed.dart';

@freezed
abstract class CheckoutSummaryEntity with _$CheckoutSummaryEntity {
  const factory CheckoutSummaryEntity({
    required double subtotal,
    required double discount,
    required double deliveryFee,
    required double platformFee,
    required double total,
    @Default(0) int itemCount,
  }) = _CheckoutSummaryEntity;
}
