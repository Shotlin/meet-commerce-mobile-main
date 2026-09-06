import 'package:bakaloo_flutter_app/features/checkout/domain/entities/coupon_entity.dart';

class CouponModel {
  const CouponModel({
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.discountAmount,
    required this.minOrderAmount,
    required this.maxDiscount,
    this.description,
    this.terms,
    this.cashbackAmount = 0,
    this.freeDelivery = false,
    this.applicableCategoryIds,
    this.applicableProductIds,
  });

  final String code;
  final CouponDiscountType discountType;
  final double discountValue;
  final double discountAmount;
  final double minOrderAmount;
  final double maxDiscount;
  final String? description;
  final String? terms;
  final double cashbackAmount;
  final bool freeDelivery;
  final List<String>? applicableCategoryIds;
  final List<String>? applicableProductIds;

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      code: _readString(json, 'code'),
      discountType: _parseDiscountType(
        _readString(
          json,
          'discountType',
          fallbackKey: 'discount_type',
          fallback: 'FLAT',
        ),
      ),
      discountValue: _readDouble(
        json,
        'discountValue',
        fallbackKey: 'discount_value',
      ),
      discountAmount: _readDouble(
        json,
        'discountAmount',
        fallbackKey: 'discount_amount',
        alternateKeys: const <String>['discount'],
      ),
      minOrderAmount: _readDouble(
        json,
        'minOrderAmount',
        fallbackKey: 'min_order_amount',
      ),
      maxDiscount: _readDouble(
        json,
        'maxDiscount',
        fallbackKey: 'max_discount',
      ),
      description: _readNullableString(
        json,
        'description',
      ),
      terms: _readTerms(json['terms']),
      cashbackAmount: _readDouble(
        json,
        'cashbackAmount',
        fallbackKey: 'cashback_amount',
      ),
      freeDelivery: json['freeDelivery'] == true || json['free_delivery'] == true,
      applicableCategoryIds: _readStringList(
        json,
        'applicableCategoryIds',
        fallbackKey: 'applicable_category_ids',
      ),
      applicableProductIds: _readStringList(
        json,
        'applicableProductIds',
        fallbackKey: 'applicable_product_ids',
      ),
    );
  }

  CouponEntity toEntity() {
    return CouponEntity(
      code: code,
      discountType: discountType,
      discountValue: discountValue,
      discountAmount: discountAmount,
      minOrderAmount: minOrderAmount,
      maxDiscount: maxDiscount,
      description: description,
      terms: terms,
      cashbackAmount: cashbackAmount,
      freeDelivery: freeDelivery,
      applicableCategoryIds: applicableCategoryIds,
      applicableProductIds: applicableProductIds,
    );
  }

  static CouponDiscountType _parseDiscountType(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'PERCENTAGE':
        return CouponDiscountType.PERCENTAGE;
      case 'CASHBACK':
        return CouponDiscountType.CASHBACK;
      case 'FREE_DELIVERY':
        return CouponDiscountType.FREE_DELIVERY;
      default:
        return CouponDiscountType.FLAT;
    }
  }

  static String _readString(
    Map<String, dynamic> json,
    String key, {
    String? fallbackKey,
    List<String> alternateKeys = const <String>[],
    String fallback = '',
  }) {
    final keys = <String>[
      key,
      if (fallbackKey != null) fallbackKey,
      ...alternateKeys,
    ];
    for (final current in keys) {
      final value = json[current];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return fallback;
  }

  static String? _readNullableString(
    Map<String, dynamic> json,
    String key, {
    String? fallbackKey,
  }) {
    final keys = <String>[
      key,
      if (fallbackKey != null) fallbackKey,
    ];
    for (final current in keys) {
      final value = json[current];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static double _readDouble(
    Map<String, dynamic> json,
    String key, {
    String? fallbackKey,
    List<String> alternateKeys = const <String>[],
  }) {
    final keys = <String>[
      key,
      if (fallbackKey != null) fallbackKey,
      ...alternateKeys,
    ];
    for (final current in keys) {
      final value = json[current];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String && value.trim().isNotEmpty) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return 0;
  }

  static List<String>? _readStringList(
    Map<String, dynamic> json,
    String key, {
    String? fallbackKey,
  }) {
    final keys = <String>[
      key,
      if (fallbackKey != null) fallbackKey,
    ];
    for (final current in keys) {
      final value = json[current];
      if (value is List) {
        final items = value
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
        if (items.isNotEmpty) {
          return items;
        }
      }
    }
    return null;
  }

  static String? _readTerms(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is List) {
      final parts = value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      if (parts.isNotEmpty) {
        return parts.join('\n');
      }
    }
    return null;
  }
}
