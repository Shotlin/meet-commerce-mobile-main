import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/core/socket/order_event_gate.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_event_handler.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_models/notification_event.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_models/order_status_event.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_models/refund_status_event.dart';
import 'package:bakaloo_flutter_app/core/constants/socket_events.dart';

void main() {
  group('OrderEventGate — duplicate & out-of-order protection', () {
    test('accepts the first event and ascending seqs', () {
      final gate = OrderEventGate();
      expect(gate.accept(key: 'order:1', seq: 10, eventId: 'a'), isTrue);
      expect(gate.accept(key: 'order:1', seq: 11, eventId: 'b'), isTrue);
    });

    test('drops an exact duplicate delivery (same eventId)', () {
      final gate = OrderEventGate();
      expect(gate.accept(key: 'order:1', seq: 10, eventId: 'a'), isTrue);
      expect(gate.accept(key: 'order:1', seq: 10, eventId: 'a'), isFalse);
    });

    test('drops a STALE event that arrives after a newer one (no rollback)', () {
      final gate = OrderEventGate();
      expect(gate.accept(key: 'order:1', seq: 20, eventId: 'new'), isTrue);
      // "PACKED" overtaken by "DELIVERED" on the wire:
      expect(gate.accept(key: 'order:1', seq: 15, eventId: 'old'), isFalse);
      expect(gate.accept(key: 'order:1', seq: 20, eventId: 'same-seq'), isFalse);
    });

    test('ordering is tracked per order — another order is unaffected', () {
      final gate = OrderEventGate();
      expect(gate.accept(key: 'order:1', seq: 100), isTrue);
      expect(gate.accept(key: 'order:2', seq: 5), isTrue);
    });

    test('events without seq (older backend) always pass', () {
      final gate = OrderEventGate();
      expect(gate.accept(key: 'order:1'), isTrue);
      expect(gate.accept(key: 'order:1'), isTrue);
    });

    test('memory is bounded', () {
      final gate = OrderEventGate(maxKeys: 5, maxEventIds: 5);
      for (var i = 0; i < 50; i++) {
        gate.accept(key: 'order:$i', seq: i + 1, eventId: 'e$i');
      }
      // oldest key evicted -> an old seq for it would be accepted again, which
      // is acceptable (REST reconcile follows every event); newest still guarded.
      expect(gate.accept(key: 'order:49', seq: 1, eventId: 'zz'), isFalse);
    });
  });

  group('wire parsing', () {
    test('OrderStatusEvent carries seq + eventId', () {
      final e = OrderStatusEvent.fromJson(<String, dynamic>{
        'orderId': 'o1',
        'status': 'DELIVERED',
        'seq': 1790000000123,
        'eventId': 'order:o1:1790000000123',
        'timestamp': '2026-10-01T05:59:00.000Z',
      });
      expect(e.orderId, 'o1');
      expect(e.status.name, 'DELIVERED');
      expect(e.seq, 1790000000123);
      expect(e.eventId, 'order:o1:1790000000123');
    });

    test('OrderStatusEvent from an older backend has null seq', () {
      final e = OrderStatusEvent.fromJson(<String, dynamic>{'orderId': 'o1', 'status': 'PACKED'});
      expect(e.seq, isNull);
    });

    test('RefundStatusEvent parses the server payload', () {
      final e = RefundStatusEvent.tryParse(<String, dynamic>{
        'orderId': 'o1',
        'refundRequestId': 'r1',
        'status': 'APPROVED',
        'amount': 76,
        'refundTo': 'WALLET',
        'event': 'REFUND_APPROVED',
        'seq': 5,
        'eventId': 'refund:r1:5',
      })!;
      expect(e.isApproved, isTrue);
      expect(e.amount, 76.0);
      expect(e.refundTo, 'WALLET');
      expect(e.seq, 5);
    });

    test('RefundStatusEvent rejects a payload with no ids', () {
      expect(RefundStatusEvent.tryParse(<String, dynamic>{'status': 'APPROVED'}), isNull);
    });

    test('SocketEventHandler routes refund:status', () {
      RefundStatusEvent? got;
      final handler = SocketEventHandler(
        onOrderStatus: (_) {},
        onRiderLocation: (_) {},
        onNotification: (NotificationEvent _) {},
        onRefundStatus: (e) => got = e,
      );
      handler.route(SocketEvents.refundStatus, <String, dynamic>{
        'orderId': 'o1',
        'refundRequestId': 'r1',
        'status': 'REJECTED',
      });
      expect(got?.status, 'REJECTED');
    });
  });
}
