// ignore_for_file: constant_identifier_names

import 'package:freezed_annotation/freezed_annotation.dart';

part 'coupon_entity.freezed.dart';

enum CouponDiscountType {
  PERCENTAGE,
  FLAT,
  CASHBACK,
  FREE_DELIVERY,
}

@freezed
abstract class CouponEntity with _$CouponEntity {
  const factory CouponEntity({
    required String code,
    required CouponDiscountType discountType,
    required double discountValue,
    required double discountAmount,
    required double minOrderAmount,
    required double maxDiscount,
    String? description,
    String? terms,
    // CASHBACK/FREE_DELIVERY coupons never reduce the bill (discountAmount
    // stays 0 for both, by backend design) — they produce a separate
    // effect instead, carried in these two fields.
    @Default(0) double cashbackAmount,
    @Default(false) bool freeDelivery,
    // Scope this coupon was validated with — null/empty on both means it
    // applies to the whole cart. Used to locally re-check "does the coupon
    // still apply?" whenever cart contents change (see
    // checkout_provider.dart#_syncCart) without another server round trip.
    List<String>? applicableCategoryIds,
    List<String>? applicableProductIds,
  }) = _CouponEntity;
}
