import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/features/orders/presentation/widgets/order_details/order_qr_payload_parser.dart';

void main() {
  group('parseFreshCutsOrderQrPayload', () {
    test('extracts the order id from a well-formed payload', () {
      expect(
        parseFreshCutsOrderQrPayload('FRESHCUTS-ORDER|FC-KOL-20260923-0001|d9782212-2852-41c7-8419-dcbc56ebe53a'),
        'd9782212-2852-41c7-8419-dcbc56ebe53a',
      );
    });

    test('tolerates surrounding whitespace from a camera scan', () {
      expect(
        parseFreshCutsOrderQrPayload('  FRESHCUTS-ORDER|FC-KOL-1|order-1  '),
        'order-1',
      );
    });

    test('rejects null input', () {
      expect(parseFreshCutsOrderQrPayload(null), isNull);
    });

    test('rejects a QR from a different app entirely', () {
      expect(parseFreshCutsOrderQrPayload('https://example.com/some-other-link'), isNull);
    });

    test('rejects a malformed FreshCuts-prefixed payload with too few segments', () {
      expect(parseFreshCutsOrderQrPayload('FRESHCUTS-ORDER|onlyonepart'), isNull);
    });

    test('rejects a well-formed prefix with an empty order id segment', () {
      expect(parseFreshCutsOrderQrPayload('FRESHCUTS-ORDER|FC-KOL-1|'), isNull);
    });

    test('rejects plain garbage text', () {
      expect(parseFreshCutsOrderQrPayload('not a qr code at all'), isNull);
    });
  });
}
