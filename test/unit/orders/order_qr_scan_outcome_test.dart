import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/features/orders/presentation/screens/order_qr_scan_outcome.dart';

const _order0001Payload = 'FRESHCUTS-ORDER|FC-KOL-20260926-0001|order-uuid-0001';
const _order0002Payload = 'FRESHCUTS-ORDER|FC-KOL-20260926-0002|order-uuid-0002';

void main() {
  group('resolveQrScanOutcome — order-scoped validation', () {
    test(
      'ALLOWS the video when the scanned QR belongs to the exact order the scanner was opened from',
      () {
        final outcome = resolveQrScanOutcome(
          rawValue: _order0002Payload,
          expectedOrderId: 'order-uuid-0002',
          expectedOrderNumber: 'FC-KOL-20260926-0002',
        );
        expect(outcome, isA<QrScanMatch>());
        expect((outcome as QrScanMatch).orderId, 'order-uuid-0002');
      },
    );

    test(
      'REJECTS a genuinely different (but otherwise valid) order\'s QR — the exact user-reported scenario: '
      'inside order 0001, scanning order 0002\'s invoice must not open any video',
      () {
        final outcome = resolveQrScanOutcome(
          rawValue: _order0002Payload,
          expectedOrderId: 'order-uuid-0001',
          expectedOrderNumber: 'FC-KOL-20260926-0001',
        );
        expect(outcome, isA<QrScanRejected>());
        expect(
          (outcome as QrScanRejected).message,
          'This QR code belongs to a different order — not FC-KOL-20260926-0001.',
        );
      },
    );

    test('REJECTS scanning your own currently-open order\'s QR the other way around too', () {
      final outcome = resolveQrScanOutcome(
        rawValue: _order0001Payload,
        expectedOrderId: 'order-uuid-0002',
        expectedOrderNumber: 'FC-KOL-20260926-0002',
      );
      expect(outcome, isA<QrScanRejected>());
    });

    test('REJECTS garbage / non-FreshCuts QR content with the existing "not a FreshCuts QR" message', () {
      final outcome = resolveQrScanOutcome(
        rawValue: 'https://example.com/some-other-qr',
        expectedOrderId: 'order-uuid-0001',
        expectedOrderNumber: 'FC-KOL-20260926-0001',
      );
      expect(outcome, isA<QrScanRejected>());
      expect((outcome as QrScanRejected).message, contains("doesn't look like a FreshCuts order QR"));
    });

    test('REJECTS a null scan (nothing decoded yet)', () {
      final outcome = resolveQrScanOutcome(
        rawValue: null,
        expectedOrderId: 'order-uuid-0001',
        expectedOrderNumber: 'FC-KOL-20260926-0001',
      );
      expect(outcome, isA<QrScanRejected>());
    });

    test(
      'ALLOWS any valid order QR when there is no expected order in scope (defensive fallback — no current call site hits this)',
      () {
        final outcome = resolveQrScanOutcome(
          rawValue: _order0002Payload,
          expectedOrderId: null,
          expectedOrderNumber: null,
        );
        expect(outcome, isA<QrScanMatch>());
      },
    );
  });
}
