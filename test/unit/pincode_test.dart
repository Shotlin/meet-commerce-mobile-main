import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/core/maps/storefront_resolver.dart';
import 'package:bakaloo_flutter_app/core/utils/pincode.dart';

void main() {
  group('normalizePincode', () {
    test('keeps a clean PIN', () => expect(normalizePincode('700001'), '700001'));

    test('strips whitespace, dashes and non-breaking spaces', () {
      expect(normalizePincode(' 700001 '), '700001');
      expect(normalizePincode('700 001'), '700001');
      expect(normalizePincode('700-001'), '700001');
      expect(normalizePincode('700 001'), '700001');
    });

    test('extracts the PIN from geocoder decorations', () {
      expect(normalizePincode('700001, India'), '700001');
      expect(normalizePincode('IN-700001'), '700001');
      expect(normalizePincode('Kolkata 700001'), '700001');
    });

    test('rejects everything that is not a standalone 6-digit PIN', () {
      for (final String? bad in <String?>[
        null,
        '',
        '   ',
        '70001',
        '7000011',
        '012345',
        'abcdef',
        '12345678',
      ]) {
        expect(normalizePincode(bad), isNull, reason: 'input: $bad');
      }
    });
  });

  group('dedupePincodes', () {
    test('normalises, drops junk and dedupes preserving first-seen order', () {
      expect(
        dedupePincodes(<String?>[
          '700 001',
          '700001',
          null,
          '',
          '201301',
          ' 700001 ',
          '20130',
          '110001',
        ]),
        <String>['700001', '201301', '110001'],
      );
    });
  });

  group('buildResolveLocationPayload', () {
    test('sends a normalised PIN and omits a missing/invalid one', () {
      expect(
        buildResolveLocationPayload(lat: 1, lng: 2, pincode: ' 201 301 '),
        <String, dynamic>{'lat': 1.0, 'lng': 2.0, 'pincode': '201301'},
      );
      expect(
        buildResolveLocationPayload(lat: 1, lng: 2, pincode: null),
        <String, dynamic>{'lat': 1.0, 'lng': 2.0},
      );
      expect(
        buildResolveLocationPayload(lat: 1, lng: 2, pincode: '2013'),
        <String, dynamic>{'lat': 1.0, 'lng': 2.0},
      );
    });
  });

  group('resolveStorefront', () {
    Map<String, dynamic> served(String shop) => <String, dynamic>{
          'serviceable': true,
          'shop': <String, dynamic>{'id': shop},
          'storefrontToken': 't-$shop',
        };
    const Map<String, dynamic> notServed = <String, dynamic>{
      'serviceable': false,
    };

    test('a served PIN resolves on the first call', () async {
      final List<Map<String, dynamic>> calls = <Map<String, dynamic>>[];
      final StorefrontResolution r = await resolveStorefront(
        lat: 28.5,
        lng: 77.4,
        candidates: <String?>['201 301'],
        call: (Map<String, dynamic> p) async {
          calls.add(p);
          return served('kolkata'); // pincode_only shop, physically far away
        },
      );
      expect(r.serviceable, isTrue);
      expect(r.pincode, '201301');
      expect(calls.single['pincode'], '201301');
    });

    test('falls through to the next geocoder PIN when the first is not served',
        () async {
      final List<String?> tried = <String?>[];
      final StorefrontResolution r = await resolveStorefront(
        lat: 1,
        lng: 2,
        candidates: <String?>['201306', '201301', '201306'],
        call: (Map<String, dynamic> p) async {
          tried.add(p['pincode'] as String?);
          return p['pincode'] == '201301' ? served('s') : notServed;
        },
      );
      expect(r.serviceable, isTrue);
      expect(r.pincode, '201301');
      expect(tried, <String?>['201306', '201301'],
          reason: 'duplicates are not retried');
    });

    test('unserviceable after every distinct PIN keeps the first PIN', () async {
      int calls = 0;
      final StorefrontResolution r = await resolveStorefront(
        lat: 1,
        lng: 2,
        candidates: <String?>['400001', '400001', ' 400 001'],
        call: (_) async {
          calls++;
          return notServed;
        },
      );
      expect(r.serviceable, isFalse);
      expect(r.pincode, '400001');
      expect(calls, 1);
    });

    test('with no PIN at all a single coordinates-only call is made', () async {
      final List<Map<String, dynamic>> calls = <Map<String, dynamic>>[];
      final StorefrontResolution r = await resolveStorefront(
        lat: 1,
        lng: 2,
        candidates: <String?>[null, '', 'junk'],
        call: (Map<String, dynamic> p) async {
          calls.add(p);
          return served('radius-shop');
        },
      );
      expect(r.serviceable, isTrue);
      expect(r.pincode, isNull);
      expect(calls.single.containsKey('pincode'), isFalse);
    });
  });
}
