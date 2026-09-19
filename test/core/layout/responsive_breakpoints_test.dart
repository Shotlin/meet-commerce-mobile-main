import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/core/layout/responsive_breakpoints.dart';

void main() {
  group('ResponsiveBreakpoints', () {
    test('keeps mobile and tablet widths out of the desktop shell', () {
      expect(ResponsiveBreakpoints.isDesktop(390), isFalse);
      expect(ResponsiveBreakpoints.isDesktop(768), isFalse);
    });

    test('keeps every supported mobile and tablet reference width adaptive',
        () {
      for (final width in <double>[360, 390, 430, 768]) {
        expect(
          ResponsiveBreakpoints.isDesktop(width),
          isFalse,
          reason: '$width px should use the mobile/tablet shell',
        );
      }
    });

    test('activates the desktop shell at the centralized threshold', () {
      expect(
        ResponsiveBreakpoints.isDesktop(ResponsiveBreakpoints.desktop),
        isTrue,
      );
      for (final width in <double>[1024, 1280, 1440, 1920]) {
        expect(
          ResponsiveBreakpoints.isDesktop(width),
          isTrue,
          reason: '$width px should use the desktop shell',
        );
      }
    });
  });
}
