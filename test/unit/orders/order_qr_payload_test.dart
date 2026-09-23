import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_details/order_qr_card.dart';

/// The Order Details "Scan / View QR" card has no backend-issued QR payload
/// to render (no `qrCode` field on the order, and no per-item batch/
/// traceability id on OrderItemEntity — see order_qr_card.dart's doc
/// comment), so it encodes the order's own real, already-existing identity
/// fields instead of inventing a fake deep link. This locks that format in.
void main() {
  test('orderQrPayload encodes the real order number and id, nothing invented', () {
    final order = OrderEntity(
      id: 'd9782212-2852-41c7-8419-dcbc56ebe53a',
      orderNumber: 'FC-KOL-20260923-0001',
      status: OrderStatus.DELIVERED,
      items: const <OrderItemEntity>[],
      subtotal: 180,
      discount: 0,
      deliveryFee: 25,
      platformFee: 5,
      total: 210,
      deliveryAddress: const <String, dynamic>{},
      paymentMethod: 'COD',
      paymentStatus: 'PAID',
      createdAt: DateTime.utc(2026, 9, 23, 11, 15, 46),
    );

    expect(
      orderQrPayload(order),
      'FRESHCUTS-ORDER|FC-KOL-20260923-0001|d9782212-2852-41c7-8419-dcbc56ebe53a',
    );
  });
}
