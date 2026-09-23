import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/features/orders/data/models/order_model.dart';

/// The Order Details screen's Payment Summary card previously showed a
/// hard-coded `Tax ₹0` row (`const taxAmount = 0.0` inside the old
/// `_PriceBreakdown` widget) instead of the real `taxAmount` the backend
/// already returns on every order (`orders.repository.js#_formatCheckoutOrder`
/// → `taxAmount: Number(row.tax_amount || 0)`). `OrderEntity`/`OrderModel`
/// never even had a `taxAmount` field to read it into. This covers the new
/// field actually being parsed off the real response shape.
void main() {
  group('OrderModel.fromJson taxAmount', () {
    test('reads a non-zero camelCase taxAmount from the API response', () {
      final json = _baseOrderJson()..['taxAmount'] = 18.5;
      final model = OrderModel.fromJson(json);

      expect(model.taxAmount, 18.5);
      expect(model.toEntity().taxAmount, 18.5);
    });

    test('also reads the snake_case tax_amount fallback', () {
      final json = _baseOrderJson()..['tax_amount'] = 12;
      final model = OrderModel.fromJson(json);

      expect(model.taxAmount, 12.0);
    });

    test('defaults to 0 when the field is absent, matching real orders today', () {
      final json = _baseOrderJson();
      final model = OrderModel.fromJson(json);

      expect(model.taxAmount, 0);
    });
  });
}

Map<String, dynamic> _baseOrderJson() => <String, dynamic>{
      'id': 'order-1',
      'orderNumber': 'FC-KOL-20260923-0001',
      'status': 'DELIVERED',
      'items': <dynamic>[],
      'subtotal': 180.0,
      'discount': 0.0,
      'deliveryFee': 25.0,
      'platformFee': 5.0,
      'total': 210.0,
      'deliveryAddress': <String, dynamic>{},
      'paymentMethod': 'COD',
      'paymentStatus': 'PAID',
      'createdAt': '2026-09-23T11:15:46.362Z',
    };
