import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';

Map<String, dynamic> _extendedJson() => <String, dynamic>{
      'imageUrl': 'https://cdn.test/header.png',
      'extendToPromoBar': true,
      'recommendedWidth': 1080,
      'topRegionHeight': 564,
      'promoRegionHeight': 161,
      'totalHeight': 725,
    };

void main() {
  group('HeaderBackgroundTheme.fromJson', () {
    test('legacy theme (only imageUrl) keeps the old single-block behaviour',
        () {
      final theme = HeaderBackgroundTheme.fromJson(<String, dynamic>{
        'imageUrl': 'https://cdn.test/header.png',
      });

      expect(theme.hasImage, isTrue);
      expect(theme.extendToPromoBar, isFalse);
      expect(theme.isExtended, isFalse);
      expect(theme.recommendedWidth, 1080);
      expect(theme.topRegionHeight, isNull);
    });

    test('parses the extended configuration written by the dashboard', () {
      final theme = HeaderBackgroundTheme.fromJson(_extendedJson());

      expect(theme.isExtended, isTrue);
      expect(theme.topRegionHeight, 564);
      expect(theme.promoRegionHeight, 161);
      expect(theme.totalHeight, 725);
      expect(theme.topFraction, closeTo(564 / 725, 1e-9));
    });

    test('toggle OFF wins even when the heights are still stored', () {
      final json = _extendedJson()..['extendToPromoBar'] = false;
      expect(HeaderBackgroundTheme.fromJson(json).isExtended, isFalse);
    });

    test('never extends without an image (e.g. stripped tab fallback)', () {
      final json = _extendedJson()..['imageUrl'] = null;
      expect(HeaderBackgroundTheme.fromJson(json).isExtended, isFalse);
      json['imageUrl'] = '   ';
      expect(HeaderBackgroundTheme.fromJson(json).isExtended, isFalse);
    });

    test('never guesses a split: toggle on but heights missing => legacy', () {
      for (final missing in <String>['topRegionHeight', 'promoRegionHeight']) {
        final json = _extendedJson()..remove(missing);
        expect(HeaderBackgroundTheme.fromJson(json).isExtended, isFalse,
            reason: 'without $missing');
      }
    });

    test('OFF-mode dashboard payload (promo 0) parses to no promo region', () {
      final theme = HeaderBackgroundTheme.fromJson(<String, dynamic>{
        'imageUrl': 'https://cdn.test/header.png',
        'extendToPromoBar': false,
        'recommendedWidth': 1080,
        'topRegionHeight': 564,
        'promoRegionHeight': 0,
        'totalHeight': 564,
      });

      expect(theme.promoRegionHeight, isNull);
      expect(theme.isExtended, isFalse);
    });

    test('is tolerant of odd JSON types instead of throwing', () {
      final theme = HeaderBackgroundTheme.fromJson(<String, dynamic>{
        'imageUrl': 'https://cdn.test/header.png',
        'extendToPromoBar': 'yes',
        'recommendedWidth': 'wide',
        'topRegionHeight': 564.0,
        'promoRegionHeight': -3,
        'totalHeight': double.nan,
      });

      expect(theme.extendToPromoBar, isFalse);
      expect(theme.recommendedWidth, 1080);
      expect(theme.topRegionHeight, 564);
      expect(theme.promoRegionHeight, isNull);
      expect(theme.totalHeight, isNull);
    });

    test('a full RemoteTheme sections payload without the field still parses',
        () {
      final sections = ThemeSections.fromJson(<String, dynamic>{});
      expect(sections.headerBackground.isExtended, isFalse);
    });
  });

  group('geometry', () {
    test('promo bar height = B scaled to the screen width', () {
      final theme = HeaderBackgroundTheme.fromJson(_extendedJson());
      expect(theme.promoBarHeightFor(1080), 161);
      expect(theme.promoBarHeightFor(540), 80.5);
      expect(theme.promoBarHeightFor(390), closeTo(161 * 390 / 1080, 1e-9));
    });

    test('fraction is exactly A / (A + B)', () {
      final theme = HeaderBackgroundTheme.fromJson(_extendedJson()
        ..['topRegionHeight'] = 600
        ..['promoRegionHeight'] = 200);
      expect(theme.topFraction, 0.75);
    });
  });

  test('toJson / fromJson round-trips and equality follows the values', () {
    final theme = HeaderBackgroundTheme.fromJson(_extendedJson());
    final again = HeaderBackgroundTheme.fromJson(theme.toJson());

    expect(again, theme);
    expect(again.hashCode, theme.hashCode);
    expect(
      HeaderBackgroundTheme.fromJson(_extendedJson()..['topRegionHeight'] = 1),
      isNot(theme),
    );
  });
}
