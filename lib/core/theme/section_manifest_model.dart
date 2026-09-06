import 'package:flutter/foundation.dart';

enum SectionType {
  animatedBanner('animated_banner'),
  feeStrip('fee_strip'),
  seasonalMosaic('seasonal_mosaic'),
  roundCategoryIcons('round_category_icons'),
  categoryProductGrid('category_product_grid'),
  productCarousel('product_carousel'),
  trendingProducts('trending_products'),
  promoCarousel('promo_carousel'),
  bankOffers('bank_offers'),
  customBanner('custom_banner'),
  textHeader('text_header'),
  archedProductShowcase('arched_product_showcase'),
  spacer('spacer');

  const SectionType(this.value);

  final String value;

  static SectionType fromString(String? rawValue) {
    final String normalized = rawValue?.trim() ?? '';
    for (final SectionType type in values) {
      if (type.value == normalized || type.name == normalized) {
        return type;
      }
    }
    return SectionType.customBanner;
  }
}

@immutable
class SectionManifestEntry {
  const SectionManifestEntry({
    required this.id,
    required this.type,
    required this.order,
    required this.visible,
    required this.config,
    required this.merchBinding,
    this.products = const <Map<String, dynamic>>[],
  });

  final String id;
  final SectionType type;
  final int order;
  final bool visible;
  final Map<String, dynamic> config;
  final Map<String, dynamic>? merchBinding;

  /// Products already resolved server-side by the public section-manifest
  /// endpoint. When a section's `merch_binding` pins `product_ids` (manual
  /// source) or `category_ids`, the backend resolves, orders and stock-filters
  /// them and returns the full product objects here. The app should prefer
  /// these over re-resolving from the home pool — this guarantees hand-picked
  /// products always render, even when they are not in the home feed's pool.
  final List<Map<String, dynamic>> products;

  factory SectionManifestEntry.fromJson(Map<String, dynamic> json) {
    return SectionManifestEntry(
      id: _parseNullableString(json['id']) ?? '',
      type: SectionType.fromString(
        _parseNullableString(json['type']) ??
            _parseNullableString(json['section_type']),
      ),
      order: _parseInt(json['order']) ?? _parseInt(json['sort_order']) ?? 0,
      visible: _parseBool(json['visible']) ?? true,
      config: _normalizeMap(json['config']),
      merchBinding: _normalizeNullableMap(
        json['merch_binding'] ?? json['merchBinding'],
      ),
      products: _parseMapList(json['products']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type.value,
      'order': order,
      'visible': visible,
      'config': config,
      if (merchBinding != null) 'merch_binding': merchBinding,
      if (products.isNotEmpty) 'products': products,
    };
  }

  String? get lottieUrl =>
      _parseNullableString(config['lottie_url'] ?? config['lottieUrl']);
  String? get imageUrl =>
      _parseNullableString(config['image_url'] ?? config['imageUrl']);
  List<String> get gradient => _parseStringList(config['gradient']);
  String? get containerColor => _parseNullableString(config['container_color']);
  double? get height => _parseDouble(config['height']);
  String? get layoutVariant => _parseNullableString(config['layout_variant']);
  String? get title => _parseNullableString(config['title']);
  int? get columns => _parseInt(config['columns']);

  /// Card shape: "arch" (default) or "wave"
  String? get cardShape => _parseNullableString(config['card_shape']);

  /// Background gradient: list of 2 hex color strings, or null for solid
  List<String> get bgGradient => _parseStringList(config['bg_gradient']);

  /// Individual card box gradient: list of 2 hex color strings, or null for solid
  List<String> get boxGradient => _parseStringList(config['box_gradient']);

  /// Arch height for the arch shape (default: 14)
  double? get archHeight => _parseDouble(config['arch_height']);

  /// Corner radius for the card (default: 24)
  double? get cornerRadius => _parseDouble(config['corner_radius']);

  // merch_binding.limit is the dashboard's canonical "Data" tab control and
  // is what the backend actually uses to slice products server-side. Prefer
  // it over the legacy config.limit (Style tab) so the two never disagree.
  int? get productLimit =>
      _parseInt(merchBinding?['limit']) ?? _parseInt(config['limit']);

  // ── Arched Showcase 2.0: Title zone ──
  bool get showTitle => _parseBool(config['show_title']) ?? true;
  String? get titleColor => _parseNullableString(config['title_color']);

  // ── Arched Showcase 2.0: Banner zone ──
  Map<String, dynamic> get archedBanner => _normalizeMap(config['banner']);
  bool get archedBannerEnabled => _parseBool(archedBanner['enabled']) ?? false;
  String get archedBannerContentSource =>
      _parseNullableString(archedBanner['content_source']) ?? 'lottie';
  String? get archedBannerLottieUrl =>
      _parseNullableString(archedBanner['lottie_url']);
  String? get archedBannerImageUrl =>
      _parseNullableString(archedBanner['image_url']);
  double get archedBannerHeight =>
      _parseDouble(archedBanner['height']) ?? 120.0;
  List<String> get archedBannerGradient =>
      _parseStringList(archedBanner['gradient']);

  // ── Arched Showcase 2.0: Category strip zone ──
  Map<String, dynamic> get archedCategoryStrip =>
      _normalizeMap(config['category_strip']);
  bool get archedCategoryStripEnabled =>
      _parseBool(archedCategoryStrip['enabled']) ?? false;
  double get archedCategoryStripIconSize =>
      _parseDouble(archedCategoryStrip['icon_size']) ?? 56.0;
  bool get archedCategoryStripShowLabels =>
      _parseBool(archedCategoryStrip['show_labels']) ?? true;

  List<Map<String, dynamic>> get archedCategoryStripItems {
    final dynamic rawItems = archedCategoryStrip['items'];
    if (rawItems is! List) return const <Map<String, dynamic>>[];
    return List<Map<String, dynamic>>.unmodifiable(
      rawItems
          .whereType<Map>()
          .map(
            (Map<dynamic, dynamic> item) => Map<String, dynamic>.from(item),
          )
          .toList(growable: false),
    );
  }

  // ── Arched Showcase 2.0: Product layout ──
  String get productLayout =>
      _parseNullableString(config['product_layout']) ?? 'horizontal_scroll';

  /// Visual style of the product cards rendered in this section, as a raw
  /// backend token (e.g. `QUICK_COMMERCE_COMPACT`, `BAKALOO_LEGACY_CLEAN`).
  ///
  /// Read from `config.product_card_style` (snake_case persisted by the
  /// dashboard) with a `productCardStyle` camelCase fallback. Returns `null`
  /// when unset so the caller can apply the global/default variant — old
  /// sections without the key keep the default quick-commerce card.
  String? get productCardStyle => _parseNullableString(
        config['product_card_style'] ?? config['productCardStyle'],
      );
}

@immutable
class SectionManifestResponse {
  const SectionManifestResponse({
    required this.tabKey,
    required this.storeKey,
    required this.sections,
    this.etag,
  });

  final String tabKey;
  final String storeKey;
  final List<SectionManifestEntry> sections;
  final String? etag;

  factory SectionManifestResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawSections =
        json['sections'] as List<dynamic>? ?? <dynamic>[];

    final List<SectionManifestEntry> parsedSections = rawSections
        .whereType<Map>()
        .map(
          (Map<dynamic, dynamic> item) => SectionManifestEntry.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((SectionManifestEntry entry) => entry.visible)
        .toList()
      ..sort(
        (SectionManifestEntry a, SectionManifestEntry b) =>
            a.order.compareTo(b.order),
      );

    return SectionManifestResponse(
      tabKey: _parseNullableString(json['tab_key']) ?? 'all',
      storeKey: _parseNullableString(json['store_key']) ?? 'zepto',
      sections: List<SectionManifestEntry>.unmodifiable(parsedSections),
      etag: _parseNullableString(json['etag']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tab_key': tabKey,
      'store_key': storeKey,
      'etag': etag,
      'sections': sections
          .map((SectionManifestEntry entry) => entry.toJson())
          .toList(growable: false),
    };
  }

  static const SectionManifestResponse empty = SectionManifestResponse(
    tabKey: 'all',
    storeKey: 'zepto',
    sections: <SectionManifestEntry>[],
  );
}

String? _parseNullableString(dynamic value) {
  if (value == null) {
    return null;
  }

  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

int? _parseInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

double? _parseDouble(dynamic value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}

bool? _parseBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    final String normalized = value.trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
  }
  return null;
}

List<String> _parseStringList(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }

  return List<String>.unmodifiable(
    value
        .where((dynamic item) => _parseNullableString(item) != null)
        .map((dynamic item) => _parseNullableString(item)!)
        .toList(growable: false),
  );
}

Map<String, dynamic> _normalizeMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.unmodifiable(
      Map<String, dynamic>.from(value),
    );
  }
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(
      Map<String, dynamic>.from(value),
    );
  }
  return const <String, dynamic>{};
}

Map<String, dynamic>? _normalizeNullableMap(dynamic value) {
  if (value == null) {
    return null;
  }
  final Map<String, dynamic> normalized = _normalizeMap(value);
  return normalized.isEmpty ? null : normalized;
}

List<Map<String, dynamic>> _parseMapList(dynamic value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return List<Map<String, dynamic>>.unmodifiable(
    value
        .whereType<Map>()
        .map((Map<dynamic, dynamic> item) => Map<String, dynamic>.from(item))
        .toList(growable: false),
  );
}
