import 'package:bakaloo_flutter_app/core/theme/section_header_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy section configs remain text-only', () {
    final SectionHeaderConfig header =
        SectionHeaderConfig.fromConfig(const <String, dynamic>{});

    expect(header.style, SectionHeaderStyle.text);
    expect(header.showText, isTrue);
    expect(header.showGraphic, isFalse);
    expect(header.aspectRatio, 3.6);
    expect(header.horizontalMargin, 16);
  });

  test('graphic-only config uses the canonical 1080 by 300 ratio', () {
    final SectionHeaderConfig header = SectionHeaderConfig.fromConfig(
      const <String, dynamic>{
        'section_header': <String, dynamic>{
          'style': 'graphic',
          'visible': true,
          'image_url': 'https://cdn.test/banner.webp',
        },
      },
    );

    expect(header.showText, isFalse);
    expect(header.showGraphic, isTrue);
    expect(header.imageUrl, 'https://cdn.test/banner.webp');
    expect(header.imageHeightFor(360), 100);
  });

  test('category grid has natural rows for ten items', () {
    expect(categoryGridRowCount(10), 3);
    expect(categoryGridRowCount(8), 2);
    expect(categoryGridRowCount(0), 0);
  });

  test('category grid caps a large icon to its calculated four-column cell',
      () {
    expect(
      categoryGridIconSize(
        availableWidth: 328,
        requestedIconSize: 96,
        gap: 12,
      ),
      73,
    );
  });
}
