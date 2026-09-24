import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/features/orders/data/models/order_item_model.dart';

/// The Order Details screen's item list previously showed no strikethrough
/// MRP or "% OFF" badge at all — the backend never captured a per-item
/// original price on a placed order. `orders.service.js#placeOrder` now
/// snapshots the cart line's real `brand`/`originalPrice`/`discountPercent`
/// onto the order at checkout time, and `orders.repository.js#_formatOrderItem`
/// surfaces them. This covers the mobile side actually reading them —
/// nothing here is invented when the fields are genuinely absent.
void main() {
  group('OrderItemModel.fromJson brand/originalPrice/discountPercent', () {
    test('reads a real discount snapshot (camelCase, the checkout-time shape)', () {
      final model = OrderItemModel.fromJson(<String, dynamic>{
        'productId': 'prod-1',
        'name': 'Chicken Breast (Boneless)',
        'price': 260,
        'quantity': 1,
        'unit': '500 g',
        'total': 260,
        'brand': 'Fresh Cuts',
        'originalPrice': 320,
        'discountPercent': 18,
      });

      expect(model.brand, 'Fresh Cuts');
      expect(model.originalPrice, 320.0);
      expect(model.discountPercent, 18);

      final entity = model.toEntity();
      expect(entity.brand, 'Fresh Cuts');
      expect(entity.originalPrice, 320.0);
      expect(entity.discountPercent, 18);
    });

    test('also reads the snake_case fallback keys', () {
      final model = OrderItemModel.fromJson(<String, dynamic>{
        'productId': 'prod-1',
        'name': 'Mutton Curry Cut',
        'price': 420,
        'quantity': 1,
        'unit': '500 g',
        'total': 420,
        'original_price': 480,
        'discount_percent': 13,
      });

      expect(model.originalPrice, 480.0);
      expect(model.discountPercent, 13);
    });

    test('never fabricates a discount when the order genuinely has none — brand null, originalPrice null, discountPercent 0', () {
      final model = OrderItemModel.fromJson(<String, dynamic>{
        'productId': 'prod-1',
        'name': 'Farm Fresh Eggs',
        'price': 180,
        'quantity': 1,
        'unit': 'Pack of 6',
        'total': 180,
      });

      expect(model.brand, isNull);
      expect(model.originalPrice, isNull);
      expect(model.discountPercent, 0);
    });
  });
}
