import 'package:bakaloo_flutter_app/features/checkout/domain/repositories/checkout_repository.dart';

class OrderModel {
  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.subtotal,
    required this.discountAmount,
    required this.deliveryFee,
    required this.platformFee,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.createdAt,
    this.couponCode,
    this.estimatedDelivery,
    this.walletAmountUsed = 0,
  });

  final String id;
  final String orderNumber;
  final String status;
  final double subtotal;
  final double discountAmount;
  final double deliveryFee;
  final double platformFee;
  final double totalAmount;
  final String paymentMethod;
  final String paymentStatus;
  final DateTime createdAt;
  final String? couponCode;
  final DateTime? estimatedDelivery;
  final double walletAmountUsed;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: _readString(json, 'id'),
      orderNumber: _readString(
        json,
        'orderNumber',
        fallbackKey: 'order_number',
      ),
      status: _readString(json, 'status', fallback: 'PENDING'),
      subtotal: _readDouble(json, 'subtotal'),
      discountAmount: _readDouble(
        json,
        'discountAmount',
        fallbackKey: 'discount_amount',
      ),
      deliveryFee: _readDouble(
        json,
        'deliveryFee',
        fallbackKey: 'delivery_fee',
      ),
      platformFee: _readDouble(
        json,
        'platformFee',
        fallbackKey: 'platform_fee',
      ),
      totalAmount: _readDouble(
        json,
        'totalAmount',
        fallbackKey: 'total_amount',
      ),
      walletAmountUsed: _readDouble(
        json,
        'walletAmountUsed',
        fallbackKey: 'wallet_amount_used',
      ),
      paymentMethod: _readString(
        json,
        'paymentMethod',
        fallbackKey: 'payment_method',
      ),
      paymentStatus: _readString(
        json,
        'paymentStatus',
        fallbackKey: 'payment_status',
        fallback: 'PENDING',
      ),
      couponCode: _readNullableString(
        json,
        'couponCode',
        fallbackKey: 'coupon_code',
      ),
      estimatedDelivery: _readDateTime(
        json,
        'estimatedDelivery',
        fallbackKey: 'estimated_delivery',
      ),
      createdAt: _readDateTime(
            json,
            'createdAt',
            fallbackKey: 'created_at',
          ) ??
          DateTime.now(),
    );
  }

  PlacedOrderEntity toEntity() {
    return PlacedOrderEntity(
      id: id,
      orderNumber: orderNumber,
      status: status,
      subtotal: subtotal,
      discountAmount: discountAmount,
      deliveryFee: deliveryFee,
      platformFee: platformFee,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      couponCode: couponCode,
      estimatedDelivery: estimatedDelivery,
      createdAt: createdAt,
      walletAmountUsed: walletAmountUsed,
    );
  }

  static String _readString(
    Map<String, dynamic> json,
    String key, {
    String? fallbackKey,
    String fallback = '',
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
  }) {
    final keys = <String>[
      key,
      if (fallbackKey != null) fallbackKey,
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

  static DateTime? _readDateTime(
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
        return DateTime.tryParse(value.trim());
      }
    }
    return null;
  }
}
