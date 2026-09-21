import 'package:flutter/material.dart';

Color _parseColor(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) {
    return fallback;
  }

  final cleaned = hex.replaceFirst('#', '');
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) {
    return fallback;
  }

  return Color(0xFF000000 | value);
}

List<Color> _parseGradient(List<dynamic>? values, List<Color> fallback) {
  if (values == null || values.length < 2) {
    return fallback;
  }

  return <Color>[
    _parseColor(_parseNullableString(values[0]), fallback[0]),
    _parseColor(_parseNullableString(values[1]), fallback[1]),
  ];
}

String _colorToHex(Color color) {
  final hex = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
  return '#${hex.toUpperCase()}';
}

List<String> _parseStringList(dynamic value, List<String> fallback) {
  if (value is! List) {
    return List<String>.from(fallback);
  }

  final parsed = value
      .whereType<String>()
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toList();
  if (parsed.isEmpty) {
    return List<String>.from(fallback);
  }

  return parsed;
}

String? _parseNullableString(dynamic value) {
  if (value is! String) {
    return null;
  }

  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<dynamic>? _asList(dynamic value) {
  return value is List ? value.cast<dynamic>() : null;
}

bool _parseBool(dynamic value, bool fallback) {
  return value is bool ? value : fallback;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

List<String> _gradientToHex(List<Color> colors) {
  return colors.map(_colorToHex).toList();
}

class TopBarTheme {
  const TopBarTheme({
    required this.backgroundColor,
    required this.textColor,
    this.colorEnabled = true,
  });

  final Color backgroundColor;
  final Color textColor;

  /// When false, [backgroundColor] is not painted (renders transparent) so a
  /// [HeaderBackgroundTheme.imageUrl] set behind the combined top bar /
  /// search zone / category tabs block shows through. Defaults to true so
  /// themes saved before this field existed keep their original solid color.
  final bool colorEnabled;

  factory TopBarTheme.fromJson(Map<String, dynamic> json) {
    final defaults = TopBarTheme.defaults();
    return TopBarTheme(
      backgroundColor: _parseColor(
        _parseNullableString(json['backgroundColor']),
        defaults.backgroundColor,
      ),
      textColor: _parseColor(
        _parseNullableString(json['textColor']),
        defaults.textColor,
      ),
      colorEnabled: _parseBool(json['colorEnabled'], defaults.colorEnabled),
    );
  }

  /// Neutral, brand-agnostic fallback used only for fields a theme omits.
  /// The real look always comes from the Theme Builder.
  factory TopBarTheme.defaults() => const TopBarTheme(
        backgroundColor: Color(0xFFFFFFFF),
        textColor: Color(0xFF1C1C1C),
        colorEnabled: true,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'backgroundColor': _colorToHex(backgroundColor),
        'textColor': _colorToHex(textColor),
        'colorEnabled': colorEnabled,
      };
}

class StoreSelectorTheme {
  const StoreSelectorTheme({
    required this.backgroundColor,
    required this.activeChipColor,
  });

  final Color backgroundColor;
  final Color activeChipColor;

  factory StoreSelectorTheme.fromJson(Map<String, dynamic> json) {
    final defaults = StoreSelectorTheme.defaults();
    return StoreSelectorTheme(
      backgroundColor: _parseColor(
        _parseNullableString(json['backgroundColor']),
        defaults.backgroundColor,
      ),
      activeChipColor: _parseColor(
        _parseNullableString(json['activeChipColor']),
        defaults.activeChipColor,
      ),
    );
  }

  factory StoreSelectorTheme.defaults() => const StoreSelectorTheme(
        backgroundColor: Color(0xFFFFFFFF),
        activeChipColor: Color(0xFFEEEEEE),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'backgroundColor': _colorToHex(backgroundColor),
        'activeChipColor': _colorToHex(activeChipColor),
      };
}

class CategoryTabsTheme {
  const CategoryTabsTheme({
    required this.visible,
    required this.textColor,
    required this.indicatorColor,
    this.backgroundColor,
    this.colorEnabled = true,
  });

  final bool visible;
  final Color textColor;
  final Color indicatorColor;

  /// Optional independent background for the category-tabs container row.
  /// When null, the parent [SearchZoneTheme.backgroundColor] is used (legacy behavior).
  final Color? backgroundColor;

  /// When false, no background color is painted for this row (renders
  /// transparent) so [HeaderBackgroundTheme.imageUrl] shows through.
  /// Defaults to true for backward compatibility.
  final bool colorEnabled;

  factory CategoryTabsTheme.fromJson(Map<String, dynamic> json) {
    final defaults = CategoryTabsTheme.defaults();
    return CategoryTabsTheme(
      visible: _parseBool(json['visible'], defaults.visible),
      textColor: _parseColor(
        _parseNullableString(json['textColor']),
        defaults.textColor,
      ),
      indicatorColor: _parseColor(
        _parseNullableString(json['indicatorColor']),
        defaults.indicatorColor,
      ),
      // backgroundColor is additive — null means "inherit from search zone" (backward compat)
      backgroundColor: json['backgroundColor'] != null
          ? _parseColor(
              _parseNullableString(json['backgroundColor']),
              defaults
                  .textColor, // dummy fallback — null is returned when key absent
            )
          : null,
      colorEnabled: _parseBool(json['colorEnabled'], defaults.colorEnabled),
    );
  }

  factory CategoryTabsTheme.defaults() => const CategoryTabsTheme(
        visible: true,
        textColor: Color(0xFF111827),
        indicatorColor: Color(0xFF111827),
        backgroundColor: null,
        colorEnabled: true,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'visible': visible,
        'textColor': _colorToHex(textColor),
        'indicatorColor': _colorToHex(indicatorColor),
        if (backgroundColor != null)
          'backgroundColor': _colorToHex(backgroundColor!),
        'colorEnabled': colorEnabled,
      };
}

class SearchZoneTheme {
  SearchZoneTheme({
    required this.backgroundColor,
    required this.waveColor,
    required this.searchHints,
    required this.promoBoxImageUrl,
    this.colorEnabled = true,
  });

  final Color backgroundColor;
  final Color waveColor;
  final List<String> searchHints;
  final String? promoBoxImageUrl;

  /// When false, [backgroundColor] is not painted (renders transparent) so a
  /// [HeaderBackgroundTheme.imageUrl] shows through. Defaults to true.
  final bool colorEnabled;

  static const List<String> _defaultSearchHints = <String>[];

  factory SearchZoneTheme.fromJson(Map<String, dynamic> json) {
    final defaults = SearchZoneTheme.defaults();
    return SearchZoneTheme(
      backgroundColor: _parseColor(
        _parseNullableString(json['backgroundColor']),
        defaults.backgroundColor,
      ),
      waveColor: _parseColor(
        _parseNullableString(json['waveColor']),
        defaults.waveColor,
      ),
      searchHints: _parseStringList(
        json['searchHints'],
        defaults.searchHints,
      ),
      promoBoxImageUrl: _parseNullableString(json['promoBoxImageUrl']),
      colorEnabled: _parseBool(json['colorEnabled'], defaults.colorEnabled),
    );
  }

  factory SearchZoneTheme.defaults() => SearchZoneTheme(
        backgroundColor: const Color(0xFFFFFFFF),
        waveColor: const Color(0xFFFFFFFF),
        searchHints: List<String>.from(_defaultSearchHints),
        promoBoxImageUrl: null,
        colorEnabled: true,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'backgroundColor': _colorToHex(backgroundColor),
        'waveColor': _colorToHex(waveColor),
        'searchHints': List<String>.from(searchHints),
        'promoBoxImageUrl': promoBoxImageUrl,
        'colorEnabled': colorEnabled,
      };
}

class BannerAnimationTheme {
  BannerAnimationTheme({
    required this.imageUrl,
    required this.lottieUrl,
    required this.backgroundGradient,
    required this.containerColor,
  });

  final String? imageUrl;
  final String? lottieUrl;
  final List<Color> backgroundGradient;
  final Color containerColor;

  factory BannerAnimationTheme.fromJson(Map<String, dynamic> json) {
    final defaults = BannerAnimationTheme.defaults();
    return BannerAnimationTheme(
      imageUrl: _parseNullableString(json['imageUrl']),
      lottieUrl: _parseNullableString(json['lottieUrl']),
      backgroundGradient: _parseGradient(
        _asList(json['backgroundGradient']),
        defaults.backgroundGradient,
      ),
      containerColor: _parseColor(
        _parseNullableString(json['containerColor']),
        defaults.containerColor,
      ),
    );
  }

  factory BannerAnimationTheme.defaults() => BannerAnimationTheme(
        imageUrl: null,
        lottieUrl: null,
        backgroundGradient: <Color>[
          const Color(0xFFF5F5F5),
          const Color(0xFFEEEEEE),
        ],
        containerColor: const Color(0xFFF5F5F5),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'imageUrl': imageUrl,
        'lottieUrl': lottieUrl,
        'backgroundGradient': _gradientToHex(backgroundGradient),
        'containerColor': _colorToHex(containerColor),
      };
}

/// A single image spanning the combined Top Bar + Search Zone + Category
/// Tabs block, painted behind them. Pair with `colorEnabled: false` on those
/// three sections' themes so their solid colors don't cover it.
class HeaderBackgroundTheme {
  const HeaderBackgroundTheme({required this.imageUrl});

  final String? imageUrl;

  factory HeaderBackgroundTheme.fromJson(Map<String, dynamic> json) =>
      HeaderBackgroundTheme(
        imageUrl: _parseNullableString(json['imageUrl']),
      );

  factory HeaderBackgroundTheme.defaults() =>
      const HeaderBackgroundTheme(imageUrl: null);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'imageUrl': imageUrl,
      };
}

class FeeStripTheme {
  const FeeStripTheme({
    required this.imageUrl,
    required this.visible,
  });

  final String? imageUrl;
  final bool visible;

  factory FeeStripTheme.fromJson(Map<String, dynamic> json) {
    final defaults = FeeStripTheme.defaults();
    return FeeStripTheme(
      imageUrl: _parseNullableString(json['imageUrl']),
      visible: _parseBool(json['visible'], defaults.visible),
    );
  }

  factory FeeStripTheme.defaults() => const FeeStripTheme(
        imageUrl: null,
        visible: true,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'imageUrl': imageUrl,
        'visible': visible,
      };
}

/// A tap action attached to a mosaic tile. Additive + nullable so legacy
/// themes (which never stored an action) keep their original behaviour of
/// navigating to the resolved product.
class MosaicTileAction {
  const MosaicTileAction({required this.type, this.value});

  /// none | product | category | tab | app_page | external_url
  final String type;
  final String? value;

  bool get isNone => type == 'none' || type.isEmpty;

  bool get isActionable {
    if (isNone) return false;
    if (type == 'tab' || type == 'app_page') {
      return value != null && value!.isNotEmpty;
    }
    if (type == 'product' || type == 'category' || type == 'external_url') {
      return value != null && value!.isNotEmpty;
    }
    return false;
  }

  static MosaicTileAction? fromJson(dynamic json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final type = _parseNullableString(map['type']);
    if (type == null || type == 'none') return null;
    return MosaicTileAction(
      type: type,
      value: _parseNullableString(map['value']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'value': value,
      };
}

class HeroTileTheme {
  HeroTileTheme({
    required this.title,
    required this.gradient,
    required this.badgeText,
    required this.badgeGradient,
    this.imageUrl,
    this.action,
    this.imageFit = 'contain',
  });

  final String title;
  final List<Color> gradient;
  final String badgeText;
  final List<Color> badgeGradient;
  final String? imageUrl;
  final MosaicTileAction? action;

  /// 'cover' = a complete, pre-designed banner meant to fill the whole
  /// tile edge-to-edge (own caption/branding already baked in — no title
  /// overlay area reserved). 'contain' (default) keeps the original
  /// product-photo look: image floats over the lower ~78% of the tile with
  /// room left above it for the title text.
  final String imageFit;

  factory HeroTileTheme.fromJson(Map<String, dynamic> json) {
    final defaults = HeroTileTheme.defaults();
    return HeroTileTheme(
      title: _parseNullableString(json['title']) ?? defaults.title,
      gradient: _parseGradient(
        _asList(json['gradient']),
        defaults.gradient,
      ),
      badgeText: _parseNullableString(json['badgeText']) ?? defaults.badgeText,
      badgeGradient: _parseGradient(
        _asList(json['badgeGradient']),
        defaults.badgeGradient,
      ),
      imageUrl: _parseNullableString(json['imageUrl']),
      action: MosaicTileAction.fromJson(json['action']),
      imageFit: _parseNullableString(json['imageFit']) ?? defaults.imageFit,
    );
  }

  // No bundled campaign copy: a mosaic tile shows only what the Theme Builder
  // configured. (This used to invent "Summer Cool Deals / BUY 2 GET 1".)
  factory HeroTileTheme.defaults() => HeroTileTheme(
        title: '',
        gradient: <Color>[
          const Color(0xFFF1F1F1),
          const Color(0xFFE6E6E6),
        ],
        badgeText: '',
        badgeGradient: <Color>[
          const Color(0xFFE6E6E6),
          const Color(0xFFDADADA),
        ],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'gradient': _gradientToHex(gradient),
        'badgeText': badgeText,
        'badgeGradient': _gradientToHex(badgeGradient),
        'imageUrl': imageUrl,
        if (action != null) 'action': action!.toJson(),
      };
}

class MiniTileTheme {
  MiniTileTheme({
    required this.title,
    required this.gradient,
    required this.imageUrl,
    this.action,
  });

  final String title;
  final List<Color> gradient;
  final String? imageUrl;
  final MosaicTileAction? action;

  factory MiniTileTheme.fromJson(
    Map<String, dynamic> json, {
    required MiniTileTheme fallback,
  }) {
    return MiniTileTheme(
      title: _parseNullableString(json['title']) ?? fallback.title,
      gradient: _parseGradient(
        _asList(json['gradient']),
        fallback.gradient,
      ),
      imageUrl: _parseNullableString(json['imageUrl']),
      action: MosaicTileAction.fromJson(json['action']),
    );
  }

  factory MiniTileTheme.defaults([int index = 0]) {
    final defaults = SeasonalMosaicTheme.defaultMiniTiles;
    final safeIndex = index >= 0 && index < defaults.length ? index : 0;
    final tile = defaults[safeIndex];
    return MiniTileTheme(
      title: tile.title,
      gradient: List<Color>.from(tile.gradient),
      imageUrl: tile.imageUrl,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'gradient': _gradientToHex(gradient),
        'imageUrl': imageUrl,
        if (action != null) 'action': action!.toJson(),
      };
}

class SeasonalMosaicTheme {
  SeasonalMosaicTheme({
    required this.containerColor,
    required this.heroTile,
    required this.miniTiles,
  });

  final Color containerColor;
  final HeroTileTheme heroTile;
  final List<MiniTileTheme> miniTiles;

  // Four neutral placeholder slots (the mosaic layout needs four). They carry
  // no campaign text; the Theme Builder supplies titles/images/gradients.
  static final List<MiniTileTheme> _defaultMiniTiles = <MiniTileTheme>[
    for (int i = 0; i < 4; i++)
      MiniTileTheme(
        title: '',
        gradient: <Color>[
          const Color(0xFFF1F1F1),
          const Color(0xFFE6E6E6),
        ],
        imageUrl: null,
      ),
  ];

  static List<MiniTileTheme> get defaultMiniTiles => _defaultMiniTiles
      .map(
        (MiniTileTheme tile) => MiniTileTheme(
          title: tile.title,
          gradient: List<Color>.from(tile.gradient),
          imageUrl: tile.imageUrl,
        ),
      )
      .toList();

  factory SeasonalMosaicTheme.fromJson(Map<String, dynamic> json) {
    final defaults = SeasonalMosaicTheme.defaults();
    final miniTilesValue = json['miniTiles'];

    final parsedMiniTiles = miniTilesValue is List
        ? List<MiniTileTheme>.generate(
            defaults.miniTiles.length,
            (int index) {
              final item = index < miniTilesValue.length
                  ? _asMap(miniTilesValue[index])
                  : <String, dynamic>{};
              return MiniTileTheme.fromJson(
                item,
                fallback: defaults.miniTiles[index],
              );
            },
          )
        : defaults.miniTiles;

    return SeasonalMosaicTheme(
      containerColor: _parseColor(
        _parseNullableString(json['containerColor']),
        defaults.containerColor,
      ),
      heroTile: HeroTileTheme.fromJson(_asMap(json['heroTile'])),
      miniTiles: parsedMiniTiles,
    );
  }

  factory SeasonalMosaicTheme.defaults() => SeasonalMosaicTheme(
        containerColor: const Color(0xFFF5F5F5),
        heroTile: HeroTileTheme.defaults(),
        miniTiles: defaultMiniTiles,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'containerColor': _colorToHex(containerColor),
        'heroTile': heroTile.toJson(),
        'miniTiles':
            miniTiles.map((MiniTileTheme tile) => tile.toJson()).toList(),
      };
}

class BankOffersTheme {
  BankOffersTheme({
    required this.visible,
    required this.bannerImageUrls,
  });

  final bool visible;
  final List<String> bannerImageUrls;

  factory BankOffersTheme.fromJson(Map<String, dynamic> json) {
    final defaults = BankOffersTheme.defaults();
    return BankOffersTheme(
      visible: _parseBool(json['visible'], defaults.visible),
      bannerImageUrls: _parseStringList(
        json['bannerImageUrls'],
        defaults.bannerImageUrls,
      ),
    );
  }

  factory BankOffersTheme.defaults() => BankOffersTheme(
        visible: true,
        bannerImageUrls: const <String>[],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'visible': visible,
        'bannerImageUrls': List<String>.from(bannerImageUrls),
      };
}

class ThemeMeta {
  const ThemeMeta({
    required this.seasonLabel,
    required this.statusBarBrightness,
  });

  final String seasonLabel;
  final String statusBarBrightness;

  factory ThemeMeta.fromJson(Map<String, dynamic> json) {
    final defaults = ThemeMeta.defaults();
    final brightness = _parseNullableString(json['statusBarBrightness']);
    return ThemeMeta(
      seasonLabel:
          _parseNullableString(json['seasonLabel']) ?? defaults.seasonLabel,
      statusBarBrightness:
          brightness == 'dark' ? 'dark' : defaults.statusBarBrightness,
    );
  }

  factory ThemeMeta.defaults() => const ThemeMeta(
        seasonLabel: '',
        statusBarBrightness: 'light',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'seasonLabel': seasonLabel,
        'statusBarBrightness': statusBarBrightness,
      };
}

class ThemeSections {
  ThemeSections({
    required this.topBar,
    required this.storeSelector,
    required this.categoryTabs,
    required this.searchZone,
    required this.bannerAnimation,
    required this.feeStrip,
    required this.seasonalMosaic,
    required this.bankOffers,
    HeaderBackgroundTheme? headerBackground,
  }) : headerBackground = headerBackground ?? HeaderBackgroundTheme.defaults();

  final TopBarTheme topBar;
  final StoreSelectorTheme storeSelector;
  final CategoryTabsTheme categoryTabs;
  final SearchZoneTheme searchZone;
  final BannerAnimationTheme bannerAnimation;
  final FeeStripTheme feeStrip;
  final SeasonalMosaicTheme seasonalMosaic;
  final BankOffersTheme bankOffers;

  /// Shared background image behind topBar + searchZone + categoryTabs.
  /// Additive — absent in themes saved before this field existed.
  final HeaderBackgroundTheme headerBackground;

  factory ThemeSections.fromJson(Map<String, dynamic> json) => ThemeSections(
        topBar: TopBarTheme.fromJson(_asMap(json['topBar'])),
        storeSelector:
            StoreSelectorTheme.fromJson(_asMap(json['storeSelector'])),
        categoryTabs: CategoryTabsTheme.fromJson(_asMap(json['categoryTabs'])),
        searchZone: SearchZoneTheme.fromJson(_asMap(json['searchZone'])),
        bannerAnimation:
            BannerAnimationTheme.fromJson(_asMap(json['bannerAnimation'])),
        feeStrip: FeeStripTheme.fromJson(_asMap(json['feeStrip'])),
        seasonalMosaic:
            SeasonalMosaicTheme.fromJson(_asMap(json['seasonalMosaic'])),
        bankOffers: BankOffersTheme.fromJson(_asMap(json['bankOffers'])),
        headerBackground:
            HeaderBackgroundTheme.fromJson(_asMap(json['headerBackground'])),
      );

  factory ThemeSections.defaults() => ThemeSections(
        topBar: TopBarTheme.defaults(),
        storeSelector: StoreSelectorTheme.defaults(),
        categoryTabs: CategoryTabsTheme.defaults(),
        searchZone: SearchZoneTheme.defaults(),
        bannerAnimation: BannerAnimationTheme.defaults(),
        feeStrip: FeeStripTheme.defaults(),
        seasonalMosaic: SeasonalMosaicTheme.defaults(),
        bankOffers: BankOffersTheme.defaults(),
        headerBackground: HeaderBackgroundTheme.defaults(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'topBar': topBar.toJson(),
        'storeSelector': storeSelector.toJson(),
        'categoryTabs': categoryTabs.toJson(),
        'searchZone': searchZone.toJson(),
        'bannerAnimation': bannerAnimation.toJson(),
        'feeStrip': feeStrip.toJson(),
        'seasonalMosaic': seasonalMosaic.toJson(),
        'bankOffers': bankOffers.toJson(),
        'headerBackground': headerBackground.toJson(),
      };
}

class RemoteTheme {
  const RemoteTheme({
    required this.sections,
    required this.meta,
  });

  final ThemeSections sections;
  final ThemeMeta meta;

  factory RemoteTheme.fromJson(Map<String, dynamic> json) => RemoteTheme(
        sections: ThemeSections.fromJson(_asMap(json['sections'])),
        meta: ThemeMeta.fromJson(_asMap(json['meta'])),
      );

  /// Neutral, brand-agnostic theme shown ONLY while a storefront's own theme
  /// is unresolved (first load of a shop). It is deliberately plain white/grey
  /// so it can never be mistaken for — or leak — any store's real theme.
  factory RemoteTheme.neutral() => RemoteTheme(
        sections: ThemeSections.defaults(),
        meta: ThemeMeta.defaults(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sections': sections.toJson(),
        'meta': meta.toJson(),
      };
}

/// ── TAB THEME CLASSES ──────────────────────────

/// A/B test data for a tab theme
class TabABTest {
  const TabABTest({
    required this.variantBData,
    required this.splitPercent,
  });

  final RemoteTheme variantBData;
  final int splitPercent;

  factory TabABTest.fromJson(Map<String, dynamic> json) => TabABTest(
        variantBData: RemoteTheme.fromJson(_asMap(json['variant_b_data'])),
        splitPercent: (json['split_percent'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'variant_b_data': variantBData.toJson(),
        'split_percent': splitPercent,
      };
}

/// A single tab's theme entry from the /theme/tabs API
class TabThemeEntry {
  const TabThemeEntry({
    required this.storeKey,
    required this.tabId,
    required this.themeId,
    required this.tabKey,
    required this.tabLabel,
    required this.tabIconUrl,
    required this.tabTextColor,
    required this.tabOrder,
    required this.variant,
    required this.themeData,
    this.isDefault = false,
    this.abTest,
  });

  final String storeKey;
  final String? tabId;
  final String? themeId;
  final String tabKey;
  final String tabLabel;
  final String? tabIconUrl;
  final Color tabTextColor;
  final int tabOrder;

  /// Admin-set flag (dashboard "Set as default") marking this tab as the one
  /// customers should land on when the app opens for this store.
  final bool isDefault;
  final String variant;
  final RemoteTheme themeData;
  final TabABTest? abTest;

  factory TabThemeEntry.fromJson(Map<String, dynamic> json) {
    final dynamic abTestRaw = json['ab_test'];
    return TabThemeEntry(
      storeKey: (json['store_key'] as String?) ?? 'zepto',
      tabId: _parseNullableString(json['tab_id']),
      themeId: _parseNullableString(json['theme_id']),
      tabKey: (json['tab_key'] as String?) ?? 'all',
      tabLabel: (json['tab_label'] as String?) ?? 'All',
      tabIconUrl: _parseNullableString(json['tab_icon_url']),
      tabTextColor: _parseColor(
        _parseNullableString(json['tab_text_color']),
        Colors.black,
      ),
      tabOrder: (json['tab_order'] as num?)?.toInt() ?? 0,
      isDefault: json['is_default'] == true,
      variant: (json['variant'] as String?) ?? 'A',
      themeData: RemoteTheme.fromJson(_asMap(json['theme_data'])),
      abTest: abTestRaw is Map<String, dynamic>
          ? TabABTest.fromJson(abTestRaw)
          : abTestRaw is Map
              ? TabABTest.fromJson(Map<String, dynamic>.from(abTestRaw))
              : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'store_key': storeKey,
        'tab_id': tabId,
        'theme_id': themeId,
        'tab_key': tabKey,
        'tab_label': tabLabel,
        'tab_icon_url': tabIconUrl,
        'tab_text_color': _colorToHex(tabTextColor),
        'tab_order': tabOrder,
        'is_default': isDefault,
        'variant': variant,
        'theme_data': themeData.toJson(),
        if (abTest != null) 'ab_test': abTest!.toJson(),
      };

  /// Resolve A/B variant: pick variant A or B based on userId hash
  RemoteTheme resolveForUser(String? userId) {
    if (abTest == null || userId == null) return themeData;
    final int bucket = userId.hashCode.abs() % 100;
    return bucket < abTest!.splitPercent ? abTest!.variantBData : themeData;
  }
}

/// Resolves which tab a store should land on when no explicit tab is
/// selected: the admin-flagged default tab, else the legacy 'all' tab, else
/// the first tab. [tabs] must be non-empty.
TabThemeEntry resolveDefaultTab(List<TabThemeEntry> tabs) {
  for (final TabThemeEntry tab in tabs) {
    if (tab.isDefault) return tab;
  }
  return tabs.firstWhere(
    (TabThemeEntry tab) => tab.tabKey == 'all',
    orElse: () => tabs.first,
  );
}

/// Full API response from GET /theme/tabs
class TabThemesResponse {
  const TabThemesResponse({
    required this.storeKey,
    required this.etag,
    required this.tabs,
    required this.tabMap,
    this.deliveryEtaMinutes,
  });

  final String storeKey;
  final String? etag;
  final List<TabThemeEntry> tabs;
  final Map<String, TabThemeEntry> tabMap;

  /// Admin-set delivery-time badge shown on the home screen header (e.g.
  /// "⚡ 45 mins delivery"). Plain display value, not a computed ETA.
  final int? deliveryEtaMinutes;

  /// The tab this store should land on when no tab is explicitly selected.
  TabThemeEntry? get defaultTabEntry =>
      tabs.isEmpty ? null : resolveDefaultTab(tabs);

  factory TabThemesResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> tabsRaw = json['tabs'] as List<dynamic>? ?? <dynamic>[];
    final List<TabThemeEntry> tabsList = tabsRaw
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (dynamic item) => TabThemeEntry.fromJson(
            Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          ),
        )
        .toList()
      ..sort(
        (TabThemeEntry a, TabThemeEntry b) => a.tabOrder.compareTo(b.tabOrder),
      );

    final Map<String, TabThemeEntry> tabMap = <String, TabThemeEntry>{
      for (final TabThemeEntry tab in tabsList) tab.tabKey: tab,
    };

    return TabThemesResponse(
      storeKey: (json['store_key'] as String?) ?? 'zepto',
      etag: _parseNullableString(json['etag']),
      tabs: tabsList,
      tabMap: tabMap,
      deliveryEtaMinutes: (json['delivery_eta_minutes'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'store_key': storeKey,
        'etag': etag,
        'tabs': tabs.map((TabThemeEntry tab) => tab.toJson()).toList(),
        'delivery_eta_minutes': deliveryEtaMinutes,
      };
}
