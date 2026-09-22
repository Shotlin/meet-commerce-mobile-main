import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/core/theme/section_header_config.dart';

void main() {
  group('SectionContainerConfig.fromConfig', () {
    test(
        'no config at all: safe defaults (white, light-gray border color, '
        'zero border width, 16px top radius)', () {
      final container = SectionContainerConfig.fromConfig(const {});

      expect(container.backgroundColor, const Color(0xFFFFFFFF));
      expect(container.borderColor, const Color(0xFFE5E7EB));
      expect(container.borderWidth, 0);
      expect(container.topRadius, 16);
    });

    test('reads every field the dashboard writes', () {
      final container = SectionContainerConfig.fromConfig(const {
        'container_background_color': '#FDF2E9',
        'container_border_color': '#D97706',
        'container_border_width': 2,
        'container_top_radius': 20,
      });

      expect(container.backgroundColor, const Color(0xFFFDF2E9));
      expect(container.borderColor, const Color(0xFFD97706));
      expect(container.borderWidth, 2);
      expect(container.topRadius, 20);
    });

    test('accepts a hex color with or without the leading #', () {
      final withHash = SectionContainerConfig.fromConfig(
          const {'container_background_color': '#112233'});
      final withoutHash = SectionContainerConfig.fromConfig(
          const {'container_background_color': '112233'});

      expect(withHash.backgroundColor, const Color(0xFF112233));
      expect(withoutHash.backgroundColor, const Color(0xFF112233));
    });

    test('an unparseable color falls back to the default rather than throwing',
        () {
      final container = SectionContainerConfig.fromConfig(const {
        'container_background_color': 'not-a-color',
        'container_border_color': 12345, // wrong type entirely
      });

      expect(container.backgroundColor,
          SectionContainerConfig.defaultBackgroundColor);
      expect(container.borderColor, SectionContainerConfig.defaultBorderColor);
    });

    test(
        'a negative border width or radius is clamped up to zero, never negative',
        () {
      final container = SectionContainerConfig.fromConfig(const {
        'container_border_width': -4,
        'container_top_radius': -10,
      });

      expect(container.borderWidth, 0);
      // -10 fails the non-negative check, so it falls back to the real default.
      expect(container.topRadius, SectionContainerConfig.defaultTopRadius);
    });

    test('a border width of exactly 0 is preserved (distinct from "unset")',
        () {
      final container = SectionContainerConfig.fromConfig(
          const {'container_border_width': 0});
      expect(container.borderWidth, 0);
    });
  });
}
