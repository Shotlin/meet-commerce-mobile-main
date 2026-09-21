import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/shared/widgets/header_background_regions.dart';

/// Stand-in for the network image: records the box it was given.
Widget _probe(String url, Alignment alignment) =>
    Container(key: ValueKey<String>('img-$alignment'), color: Colors.pink);

HeaderBackgroundTheme _theme({bool extend = true}) =>
    HeaderBackgroundTheme.fromJson(<String, dynamic>{
      'imageUrl': 'https://cdn.test/header.png',
      'extendToPromoBar': extend,
      'topRegionHeight': 564,
      'promoRegionHeight': 161,
      'totalHeight': 725,
    });

Future<Size> _imageBox(WidgetTester tester, Alignment alignment) async {
  return tester.getSize(find.byKey(ValueKey<String>('img-$alignment')));
}

void main() {
  testWidgets(
      'top slice: image is sized so the region shows exactly A/(A+B) of it, '
      'top-anchored', (tester) async {
    const width = 390.0;
    const regionHeight = 200.0;
    final fraction = _theme().topFraction;

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Center(
          child: SizedBox(
            width: width,
            height: regionHeight,
            child: HeaderBackgroundSlice(
              imageUrl: 'https://cdn.test/header.png',
              topFraction: fraction,
              showTop: true,
              debugImageBuilder: _probe,
            ),
          ),
        ),
      ),
    ));

    final box = await _imageBox(tester, Alignment.topCenter);
    expect(box.width, width);
    expect(box.height, closeTo(regionHeight / fraction, 1e-6));
    // The overflowing bottom part is clipped, not painted.
    expect(find.byType(ClipRect), findsWidgets);
  });

  testWidgets('promo bar: exact height from B, shows the bottom slice',
      (tester) async {
    const width = 390.0;
    final theme = _theme();

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: HeaderPromoBar(
              headerBackground: theme,
              debugImageBuilder: _probe,
            ),
          ),
        ),
      ),
    ));

    final bar = tester.getSize(find.byType(HeaderPromoBar));
    expect(bar.width, width);
    expect(bar.height, closeTo(161 * width / 1080, 1e-6));

    final box = await _imageBox(tester, Alignment.bottomCenter);
    expect(box.height, closeTo(bar.height / (1 - theme.topFraction), 1e-6));
  });

  testWidgets(
      'continuity: on a device whose header is proportional to the design, '
      'both regions render the image at the SAME scale (one asset, no seam '
      'jump, no stretching)', (tester) async {
    const width = 390.0;
    final theme = _theme();
    final topHeight = 564 * width / 1080; // A at this screen width

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Column(
          children: <Widget>[
            SizedBox(
              width: width,
              height: topHeight,
              child: HeaderBackgroundSlice(
                imageUrl: theme.imageUrl!,
                topFraction: theme.topFraction,
                showTop: true,
                debugImageBuilder: _probe,
              ),
            ),
            SizedBox(
              width: width,
              child: HeaderPromoBar(
                headerBackground: theme,
                debugImageBuilder: _probe,
              ),
            ),
          ],
        ),
      ),
    ));

    final topImage = await _imageBox(tester, Alignment.topCenter);
    final promoImage = await _imageBox(tester, Alignment.bottomCenter);
    expect(topImage.height, closeTo(promoImage.height, 1e-6));
    // ...and that height is the whole 1080×725 asset scaled to the screen.
    expect(topImage.height, closeTo(width * 725 / 1080, 1e-6));
  });

  testWidgets('promo bar renders nothing unless the header is extended',
      (tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 390,
            child: HeaderPromoBar(
              headerBackground: _theme(extend: false),
              debugImageBuilder: _probe,
            ),
          ),
        ),
      ),
    ));

    expect(tester.getSize(find.byType(HeaderPromoBar)).height, 0);
    expect(find.byType(Container), findsNothing);
  });
}
