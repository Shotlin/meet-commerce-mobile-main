import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_offer_entity.freezed.dart';
part 'payment_offer_entity.g.dart';

double _paymentOfferAmountFromJson(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}

double? _paymentOfferNullableAmountFromJson(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

@freezed
abstract class PaymentOfferEntity with _$PaymentOfferEntity {
  const PaymentOfferEntity._();

  const factory PaymentOfferEntity({
    required String id,
    required String title,
    required String provider,
    required bool isLocked,
    String? description,
    String? iconUrl,
    @Default('FLAT') String cashbackType,
    @Default(0)
    @JsonKey(fromJson: _paymentOfferAmountFromJson)
    double cashbackAmount,
    @JsonKey(fromJson: _paymentOfferNullableAmountFromJson)
    double? cashbackPercent,
    @JsonKey(fromJson: _paymentOfferNullableAmountFromJson)
    double? maxCashback,
    @Default(0)
    @JsonKey(fromJson: _paymentOfferAmountFromJson)
    double minOrderAmount,
    String? lockMessage,
    @Default(0)
    @JsonKey(fromJson: _paymentOfferAmountFromJson)
    double unlockProgress,
  }) = _PaymentOfferEntity;

  factory PaymentOfferEntity.fromJson(Map<String, dynamic> json) =>
      _$PaymentOfferEntityFromJson(json);

  bool get isPercentage => cashbackType == 'PERCENTAGE';

  /// e.g. "80% cashback, up to ₹50" or "₹10 cashback"
  String get cashbackLabel {
    if (isPercentage && cashbackPercent != null) {
      final percent = cashbackPercent!.toStringAsFixed(
        cashbackPercent! % 1 == 0 ? 0 : 1,
      );
      if (maxCashback != null) {
        final cap = maxCashback!.toStringAsFixed(
          maxCashback! % 1 == 0 ? 0 : 1,
        );
        return '$percent% cashback, up to ₹$cap';
      }
      return '$percent% cashback';
    }
    final amount = cashbackAmount.toStringAsFixed(
      cashbackAmount % 1 == 0 ? 0 : 1,
    );
    return '₹$amount cashback';
  }
}
