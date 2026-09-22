enum SectionHeaderStyle {
  text,
  graphic,
  textGraphic,
}

class SectionHeaderConfig {
  const SectionHeaderConfig({
    required this.style,
    required this.imageUrl,
    required this.visible,
    required this.aspectRatio,
    required this.borderRadius,
    required this.horizontalMargin,
    required this.bottomSpacing,
    required this.linkUrl,
  });

  static const double canonicalAspectRatio = 1080 / 300;

  final SectionHeaderStyle style;
  final String? imageUrl;
  final bool visible;
  final double aspectRatio;
  final double borderRadius;
  final double horizontalMargin;
  final double bottomSpacing;
  final String? linkUrl;

  bool get showText => style != SectionHeaderStyle.graphic;
  bool get showGraphic =>
      style != SectionHeaderStyle.text && visible && imageUrl != null;

  double imageHeightFor(double availableWidth) => availableWidth / aspectRatio;

  factory SectionHeaderConfig.fromConfig(Map<String, dynamic> config) {
    final dynamic rawHeader = config['section_header'];
    final Map<String, dynamic> header = rawHeader is Map
        ? Map<String, dynamic>.from(rawHeader)
        : const <String, dynamic>{};
    final String styleValue = _readString(header['style']) ?? 'text';
    return SectionHeaderConfig(
      style: switch (styleValue) {
        'graphic' => SectionHeaderStyle.graphic,
        'text_graphic' => SectionHeaderStyle.textGraphic,
        _ => SectionHeaderStyle.text,
      },
      imageUrl: _readString(header['image_url']),
      visible: _readBool(header['visible']) ?? true,
      aspectRatio: _readPositiveDouble(
            header['image_aspect_ratio'],
          ) ??
          canonicalAspectRatio,
      borderRadius: _readNonNegativeDouble(header['border_radius']) ?? 14,
      horizontalMargin:
          _readNonNegativeDouble(header['horizontal_margin']) ?? 16,
      bottomSpacing: _readNonNegativeDouble(header['bottom_spacing']) ?? 12,
      linkUrl: _readString(header['link_url']),
    );
  }
}

class CategorySectionLayoutConfig {
  const CategorySectionLayoutConfig({
    required this.isGrid,
    required this.columns,
    required this.iconSize,
    required this.gap,
    required this.rowGap,
    required this.showLabels,
  });

  final bool isGrid;
  final int columns;
  final double iconSize;
  final double gap;
  final double rowGap;
  final bool showLabels;

  factory CategorySectionLayoutConfig.fromConfig(Map<String, dynamic> config) {
    return CategorySectionLayoutConfig(
      isGrid: _readString(config['layout_mode']) == 'grid',
      // The Premium Fresh category layout intentionally has one mobile
      // column contract: exactly four calculated columns, never a fixed tile
      // width that can overflow on narrow phones.
      columns: 4,
      iconSize: (_readPositiveDouble(config['icon_size']) ?? 64).clamp(40, 96),
      gap: (_readNonNegativeDouble(config['gap']) ?? 12).clamp(4, 24),
      rowGap: (_readNonNegativeDouble(config['row_gap']) ?? 14).clamp(4, 32),
      showLabels: _readBool(config['show_labels']) ?? true,
    );
  }
}

int categoryGridRowCount(int itemCount, {int columns = 4}) {
  if (itemCount <= 0) {
    return 0;
  }
  return (itemCount / columns.clamp(1, 4)).ceil();
}

double categoryGridIconSize({
  required double availableWidth,
  required double requestedIconSize,
  required double gap,
}) {
  final double cellWidth =
      ((availableWidth - (gap * 3)) / 4).clamp(0, double.infinity).toDouble();
  return requestedIconSize.clamp(0, cellWidth).toDouble();
}

String? _readString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

bool? _readBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
        return true;
      case 'false':
        return false;
    }
  }
  return null;
}

double? _readPositiveDouble(dynamic value) {
  final double? result = _readDouble(value);
  return result != null && result > 0 ? result : null;
}

double? _readNonNegativeDouble(dynamic value) {
  final double? result = _readDouble(value);
  return result != null && result >= 0 ? result : null;
}

double? _readDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}
