import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/core/maps/geo_point.dart';
import 'package:bakaloo_flutter_app/core/maps/storefront_location_payload.dart';

void main() {
  // Physically inside PIN 201301 (Noida). The store serving it is in Kolkata
  // and is configured "match by pincode list only".
  const GeoPoint noida = GeoPoint(lat: 28.5355, lng: 77.3910);

  group('normalizePincode', () {
    test('accepts a clean 6-digit PIN', () {
      expect(normalizePincode('201301'), '201301');
    });

    test('strips surrounding and inner whitespace', () {
      expect(normalizePincode(' 201301 '), '201301');
      expect(normalizePincode('201 301'), '201301');
      expect(normalizePincode('\t201301\n'), '201301');
    });

    test('returns null for null, blank or malformed values', () {
      expect(normalizePincode(null), isNull);
      expect(normalizePincode(''), isNull);
      expect(normalizePincode('   '), isNull);
      expect(normalizePincode('2013'), isNull);
      expect(normalizePincode('20130a'), isNull);
      expect(normalizePincode('012345'), isNull);
      expect(normalizePincode('2013011'), isNull);
    });
  });

  group('buildResolveLocationPayload', () {
    test('sends lat, lng AND pincode when the PIN is known (the fix)', () {
      expect(
        buildResolveLocationPayload(noida, pincode: '201301'),
        <String, dynamic>{'lat': 28.5355, 'lng': 77.3910, 'pincode': '201301'},
      );
    });

    test('normalises the PIN before sending it', () {
      expect(
        buildResolveLocationPayload(noida, pincode: ' 201 301 ')['pincode'],
        '201301',
      );
    });

    test('omits the pincode key when there is none, keeping radius matching', () {
      final Map<String, dynamic> payload = buildResolveLocationPayload(noida);
      expect(payload, <String, dynamic>{'lat': 28.5355, 'lng': 77.3910});
      expect(payload.containsKey('pincode'), isFalse);
    });

    test('omits a blank or malformed PIN instead of sending garbage', () {
      expect(
        buildResolveLocationPayload(noida, pincode: '').containsKey('pincode'),
        isFalse,
      );
      expect(
        buildResolveLocationPayload(noida, pincode: 'abc')
            .containsKey('pincode'),
        isFalse,
      );
    });
  });
}
