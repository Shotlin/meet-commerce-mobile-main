import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_model.dart';
import 'package:bakaloo_flutter_app/core/theme/section_header_config.dart';
import 'package:bakaloo_flutter_app/features/categories/domain/entities/category_entity.dart';
import 'package:bakaloo_flutter_app/features/categories/presentation/providers/category_provider.dart';
import 'package:bakaloo_flutter_app/features/home/domain/entities/banner_entity.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/providers/banner_provider.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/providers/home_provider.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/widgets/animated_banner_section.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/widgets/custom_banner_section.dart';
// PHASE 2C: Import memoized pool provider from dedicated provider file.
import 'package:bakaloo_flutter_app/features/home/presentation/providers/home_product_pool_provider.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/providers/manual_products_provider.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/widgets/seasonal_deal_mosaic.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/widgets/spacer_section.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/widgets/text_header_section.dart';
import 'package:bakaloo_flutter_app/features/products/data/models/product_model.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/shared/widgets/arched_product_layouts.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';
import 'package:bakaloo_flutter_app/shared/widgets/product_card.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';

typedef SectionBuilder = Widget Function(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
);

double _horizontalSectionExtent(
  int index,
  int itemCount,
  double itemWidth,
  double separatorWidth,
) {
  if (itemCount <= 1 || index == itemCount - 1) {
    return itemWidth;
  }
  return itemWidth + separatorWidth;
}

final Map<SectionType, SectionBuilder> sectionRegistry =
    <SectionType, SectionBuilder>{
  SectionType.animatedBanner: _buildAnimatedBanner,
  SectionType.feeStrip: _buildFeeStrip,
  SectionType.seasonalMosaic: _buildSeasonalMosaic,
  SectionType.roundCategoryIcons: _buildRoundCategoryIcons,
  SectionType.categoryProductGrid: _buildCategoryProductGrid,
  SectionType.productCarousel: _buildProductCarousel,
  SectionType.trendingProducts: _buildTrendingProducts,
  SectionType.promoCarousel: _buildPromoCarousel,
  SectionType.bankOffers: _buildBankOffers,
  SectionType.customBanner: _buildCustomBanner,
  SectionType.textHeader: _buildTextHeader,
  SectionType.archedProductShowcase: _buildArchedProductShowcase,
  SectionType.spacer: _buildSpacer,
};

Widget _buildAnimatedBanner(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  final fallback = theme.sections.bannerAnimation;
  return AnimatedBannerSection(
    // No local fallback asset — if the dashboard doesn't configure a remote
    // lottie/image URL, the banner renders only the gradient background.
    assetPath: _readString(entry.config['fallback_asset']) ?? '',
    height: entry.height ?? 120,
    linkUrl: _readString(entry.config['link_url']),
    bannerTheme: BannerAnimationTheme(
      imageUrl: entry.imageUrl ?? fallback.imageUrl,
      lottieUrl: entry.lottieUrl ?? fallback.lottieUrl,
      backgroundGradient: _resolveGradient(
        entry.config['gradient'],
        fallback.backgroundGradient,
      ),
      containerColor: _resolveColor(
        entry.containerColor,
        fallback.containerColor,
      ),
    ),
    feeStripTheme: const FeeStripTheme(
      imageUrl: null,
      visible: false,
    ),
  );
}

Widget _buildFeeStrip(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  return _ManifestFeeStrip(
    imageUrl: _readString(entry.config['image_url']) ??
        theme.sections.feeStrip.imageUrl,
    containerColor: _resolveColor(
      entry.containerColor,
      const Color(0xFFBFEFFF),
    ),
  );
}

Widget _buildSeasonalMosaic(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  final products = _resolveProducts(ref, entry, fallbackLimit: 8);
  if (products.isEmpty) {
    return const SizedBox.shrink();
  }

  final fallback = theme.sections.seasonalMosaic;

  // V2: prefer the rich `hero_tile` object; fall back to legacy flat keys.
  final heroTileConfig = _asConfigMap(entry.config['hero_tile']);
  final heroGradient = _resolveGradient(
    heroTileConfig?['gradient'] ?? entry.config['hero_gradient'],
    fallback.heroTile.gradient,
  );
  // An admin who explicitly clears a title/badge to "" (e.g. because the
  // uploaded image already has its own caption baked in) means "show
  // nothing" — not "not customized, fall back to the default text". Only
  // fall through to the legacy keys/defaults when the tile's own config
  // never had the key at all, so an explicit empty string is respected.
  final String heroTitle =
      heroTileConfig != null && heroTileConfig.containsKey('title')
          ? (_readString(heroTileConfig['title']) ?? '')
          : _readString(entry.config['hero_title']) ??
              entry.title ??
              fallback.heroTile.title;
  final String heroBadgeText =
      heroTileConfig != null && heroTileConfig.containsKey('badge_text')
          ? (_readString(heroTileConfig['badge_text']) ?? '')
          : _readString(entry.config['hero_badge_text']) ??
              fallback.heroTile.badgeText;
  final heroTheme = HeroTileTheme(
    title: heroTitle,
    gradient: heroGradient,
    badgeText: heroBadgeText,
    badgeGradient: _resolveGradient(
      heroTileConfig?['badge_gradient'],
      fallback.heroTile.badgeGradient,
    ),
    imageUrl: _readString(heroTileConfig?['image_url']),
    action: MosaicTileAction.fromJson(heroTileConfig?['action']),
    imageFit: _readString(heroTileConfig?['image_fit']) ?? 'contain',
  );

  final miniTiles = _buildManifestMiniTiles(entry, fallback);

  final mosaicTheme = SeasonalMosaicTheme(
    containerColor:
        _resolveColor(entry.containerColor, fallback.containerColor),
    heroTile: heroTheme,
    miniTiles: miniTiles,
  );
  final heroCandidates = _mergeUniqueProducts(
    <List<ProductEntity>>[
      _resolveTrendingPool(ref),
      _resolveFeaturedPool(ref),
      products,
    ],
  );

  return SeasonalDealMosaic(
    products: products,
    heroCandidates: heroCandidates,
    mosaicTheme: mosaicTheme,
    layoutVariant: entry.layoutVariant ?? 'hero_plus_four',
  );
}

Map<String, dynamic>? _asConfigMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

/// Builds the mosaic mini tiles from the section config `mini_tiles` array,
/// falling back to the global preset tiles when the section has none (legacy).
List<MiniTileTheme> _buildManifestMiniTiles(
  SectionManifestEntry entry,
  SeasonalMosaicTheme fallback,
) {
  final raw = entry.config['mini_tiles'];
  if (raw is! List || raw.isEmpty) {
    return fallback.miniTiles;
  }

  return List<MiniTileTheme>.generate(raw.length, (int index) {
    final map = _asConfigMap(raw[index]) ?? <String, dynamic>{};
    final fb = fallback.miniTiles.isEmpty
        ? MiniTileTheme.defaults(index)
        : fallback.miniTiles[index % fallback.miniTiles.length];
    return MiniTileTheme(
      // Same "explicit empty means no title" rule as the hero tile above.
      title: map.containsKey('title')
          ? (_readString(map['title']) ?? '')
          : fb.title,
      gradient: _resolveGradient(map['gradient'], fb.gradient),
      imageUrl: _readString(map['image_url']),
      action: MosaicTileAction.fromJson(map['action']),
    );
  });
}

Widget _buildRoundCategoryIcons(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  final List<_CategoryRailItem> configuredItems =
      _resolveConfiguredCategoryRailItems(ref, entry);
  final CategorySectionLayoutConfig layout =
      CategorySectionLayoutConfig.fromConfig(entry.config);
  final SectionHeaderConfig header =
      SectionHeaderConfig.fromConfig(entry.config);

  if (configuredItems.isNotEmpty) {
    return _ManifestCategorySection(
      title: entry.title,
      subtitle: _readString(entry.config['subtitle']),
      header: header,
      items: configuredItems,
      layout: layout,
    );
  }

  final categories = _resolveCategories(ref, entry);
  if (categories.isEmpty) {
    return const SizedBox.shrink();
  }

  return _ManifestCategorySection(
    title: entry.title,
    subtitle: _readString(entry.config['subtitle']),
    header: header,
    items: categories
        .map(
          (CategoryEntity category) => _CategoryRailItem(
            label: category.name,
            imageUrl: category.imageUrl,
            categoryId: category.id,
          ),
        )
        .toList(growable: false),
    layout: layout,
  );
}

Widget _buildCategoryProductGrid(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  final products = _resolveProducts(ref, entry, fallbackLimit: 12);
  if (products.isEmpty) {
    return const SizedBox.shrink();
  }

  final premium = entry.productCardStyle == null ||
      entry.productCardStyle == 'PREMIUM_FRESH';
  final SectionHeaderConfig header =
      SectionHeaderConfig.fromConfig(entry.config);
  final columns = (entry.columns ?? (premium ? 1 : 3))
      .clamp(premium ? 1 : 2, premium ? 2 : 3);
  // A premium section sells a product family, not every individual size as a
  // separate tile.  This keeps Fish, Mutton and every other theme-builder
  // grid consistent with the All tab: one card plus its size/pack chips.
  final displayProducts = premium
      ? _mergeUniqueProducts(<List<ProductEntity>>[products])
      : products;
  return _ManifestProductGridSection(
    title: entry.title ?? 'Products for you',
    // Render every product the manifest already resolved (already capped by
    // entry.productLimit server-side) — don't re-truncate to a fixed row
    // count here, or picks beyond 2 rows silently disappear.
    products: displayProducts,
    columns: columns,
    variant:
        productCardVariantFromString(entry.productCardStyle ?? 'PREMIUM_FRESH'),
    subtitle: entry.config['subtitle'] is String
        ? entry.config['subtitle'] as String
        : null,
    header: header,
  );
}

Widget _buildProductCarousel(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  final products = _resolveProducts(ref, entry, fallbackLimit: 10);
  if (products.isEmpty) {
    return const SizedBox.shrink();
  }

  return _ManifestHorizontalProductSection(
    title: entry.title ?? 'Fresh picks',
    products: products,
    variant:
        productCardVariantFromString(entry.productCardStyle ?? 'PREMIUM_FRESH'),
    subtitle: entry.config['subtitle'] is String
        ? entry.config['subtitle'] as String
        : null,
    header: SectionHeaderConfig.fromConfig(entry.config),
  );
}

Widget _buildTrendingProducts(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  final products = _resolveProducts(
    ref,
    entry,
    fallbackProducts: _resolveTrendingPool(ref),
    fallbackLimit: 8,
  );
  if (products.isEmpty) {
    return const SizedBox.shrink();
  }

  return _ManifestHorizontalProductSection(
    title: entry.title ?? 'Trending Near You',
    products: products,
    accentColor: const Color(0xFF0D8320),
    variant: productCardVariantFromString(entry.productCardStyle),
  );
}

Widget _buildPromoCarousel(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  final items = _resolvePromoItems(ref, entry);
  if (items.isEmpty) {
    return const SizedBox.shrink();
  }

  return _ManifestPromoCarousel(
    items: items,
    borderRadius: _readDouble(entry.config['border_radius']) ?? 18,
    aspectRatio: _parseAspectRatio(entry.config['aspect_ratio']) ?? (16 / 8.8),
    autoScroll: _readBool(entry.config['auto_scroll']) ?? true,
    autoScrollSpeedMs: _readInt(entry.config['auto_scroll_speed']) ?? 3000,
  );
}

Widget _buildBankOffers(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  final List<String> configuredUrls =
      _readStringList(entry.config['image_urls']);
  final String? legacyUrl = _readString(entry.config['image_url']);
  final List<String> urls = configuredUrls.isNotEmpty
      ? configuredUrls
      : legacyUrl != null && legacyUrl.trim().isNotEmpty
          ? <String>[legacyUrl]
          : theme.sections.bankOffers.bannerImageUrls;
  final items = urls
      .take(10)
      .map(
        (String url) => _PromoItem(
          imageUrl: url,
          linkUrl: _readString(entry.config['link_url']),
        ),
      )
      .where((item) => item.imageUrl.trim().isNotEmpty)
      .toList(growable: false);
  if (items.isEmpty) {
    return const SizedBox.shrink();
  }

  return _ManifestBankOffersRow(items: items);
}

Widget _buildCustomBanner(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  return CustomBannerSection(
    imageUrl: entry.imageUrl,
    linkUrl: _readString(entry.config['link_url']),
    borderRadius: _readDouble(entry.config['border_radius']) ?? 12,
    aspectRatio: _parseAspectRatio(entry.config['aspect_ratio']),
  );
}

Widget _buildTextHeader(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  return TextHeaderSection(
    text: _readString(entry.config['text']) ??
        entry.title ??
        theme.meta.seasonLabel,
    fontSize: _readDouble(entry.config['font_size']) ?? 18,
    color: _readString(entry.config['color']) ?? '#000000',
    alignment: _readString(entry.config['alignment']) ?? 'left',
  );
}

Widget _buildSpacer(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  return SpacerSection(height: entry.height ?? 16);
}

List<CategoryEntity> _resolveCategories(
  WidgetRef ref,
  SectionManifestEntry entry,
) {
  final categoriesAsync = ref.watch(categoryCollectionProvider);
  final categories = categoriesAsync.asData?.value ?? const <CategoryEntity>[];
  final activeCategories = categories.where((category) => category.isActive);
  final selectedIds = _readStringList(entry.merchBinding?['category_ids']);

  final List<CategoryEntity> preferred = selectedIds.isNotEmpty
      ? activeCategories
          .where(
            (category) =>
                selectedIds.contains(category.id) ||
                (category.parentId != null &&
                    selectedIds.contains(category.parentId)),
          )
          .toList(growable: false)
      : activeCategories
          .where((category) => category.isParent)
          .toList(growable: false);

  final result = (preferred.isNotEmpty
      ? preferred
      : activeCategories.toList(growable: false))
    ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
  return result.take(10).toList(growable: false);
}

List<_CategoryRailItem> _resolveConfiguredCategoryRailItems(
  WidgetRef ref,
  SectionManifestEntry entry,
) {
  final dynamic rawItems = entry.config['items'];
  if (rawItems is! List) {
    return const <_CategoryRailItem>[];
  }

  final categoriesAsync = ref.watch(categoryCollectionProvider);
  final List<CategoryEntity> categories =
      categoriesAsync.asData?.value ?? const <CategoryEntity>[];
  final Map<String, CategoryEntity> categoryById = <String, CategoryEntity>{
    for (final CategoryEntity category in categories) category.id: category,
  };

  final List<_CategoryRailItem> items = <_CategoryRailItem>[];
  for (final dynamic rawItem in rawItems) {
    if (rawItem is! Map) {
      continue;
    }

    final Map<String, dynamic> item = Map<String, dynamic>.from(rawItem);
    final String? categoryId = _readString(item['category_id']);
    final String? labelOverride = _readString(item['label']);
    final String? imageOverride = _readString(item['image_url']);
    final CategoryEntity? linkedCategory =
        categoryId == null ? null : categoryById[categoryId];
    final String? resolvedLabel = labelOverride ?? linkedCategory?.name;
    final String? resolvedImageUrl = imageOverride ?? linkedCategory?.imageUrl;

    if ((resolvedLabel == null || resolvedLabel.isEmpty) &&
        (resolvedImageUrl == null || resolvedImageUrl.isEmpty)) {
      continue;
    }

    items.add(
      _CategoryRailItem(
        label: resolvedLabel ?? 'Category',
        imageUrl: resolvedImageUrl,
        categoryId: categoryId,
      ),
    );
  }

  return items.take(10).toList(growable: false);
}

List<ProductEntity> _resolveProducts(
  WidgetRef ref,
  SectionManifestEntry entry, {
  List<ProductEntity>? fallbackProducts,
  int fallbackLimit = 6,
}) {
  final binding = entry.merchBinding ?? const <String, dynamic>{};
  final limit = entry.productLimit ?? fallbackLimit;

  // PRIMARY PATH: use the products the backend already resolved for this
  // section. The public section-manifest endpoint resolves `merch_binding`
  // (manual `product_ids` + optional category fill) server-side and returns
  // the ordered, stock-filtered product objects in `entry.products`. Preferring
  // them guarantees hand-picked grids render exactly what the dashboard pinned,
  // even when those products are not part of the home feed's product pool.
  //
  // Only clamp when the admin explicitly configured a limit for THIS
  // section (`entry.productLimit`). Falling back to the generic
  // `fallbackLimit` here — as this used to do — silently re-truncated an
  // already-complete, backend-resolved list, which was the root cause of
  // "some products in a category-linked section don't show up": the
  // backend correctly sent every product, but this widget only rendered
  // the first 6-12 of them.
  final List<ProductEntity> resolvedFromManifest =
      _parseManifestProducts(entry);
  if (resolvedFromManifest.isNotEmpty) {
    return entry.productLimit != null
        ? resolvedFromManifest.take(entry.productLimit!).toList(growable: false)
        : resolvedFromManifest;
  }

  final source = _readString(binding['source']) ?? 'category';
  final basePool = fallbackProducts ?? _resolveDefaultProductPool(ref);

  if (source == 'manual') {
    final productIds = _readStringList(binding['product_ids']);
    if (productIds.isNotEmpty) {
      // First try to resolve from the already-loaded pool (fast path)
      final fromPool = _filterByIds(basePool, productIds);
      if (fromPool.length >= productIds.length) {
        // All products found in pool — use directly
        return fromPool.take(limit).toList(growable: false);
      }
      // Some products missing from pool — fetch them directly from API
      // This handles products from categories not loaded on the home feed
      final fetched = ref
          .watch(manualProductsByIdsProvider(productIds.join(',')))
          .asData
          ?.value;
      if (fetched != null && fetched.isNotEmpty) {
        return fetched.take(limit).toList(growable: false);
      }
      // Fall back to what we have from pool while API loads
      if (fromPool.isNotEmpty) {
        return fromPool.take(limit).toList(growable: false);
      }
    }
  }

  if (source == 'tag') {
    final tags = _readStringList(binding['tags']);
    final tagged = _filterByTags(basePool, tags);
    if (tagged.isNotEmpty) {
      return tagged.take(limit).toList(growable: false);
    }
  }

  final categoryIds = _readStringList(binding['category_ids']);
  if (categoryIds.isNotEmpty) {
    final scoped = <ProductEntity>[];
    for (final categoryId in categoryIds.take(4)) {
      final productsAsync = ref.watch(homeCategoryProductsProvider(categoryId));
      final categoryProducts =
          productsAsync.asData?.value ?? const <ProductEntity>[];
      scoped.addAll(categoryProducts.where((product) => product.inStock));
    }
    final merged = _mergeUniqueProducts(<List<ProductEntity>>[
      scoped,
      basePool,
    ]);
    if (merged.isNotEmpty) {
      return merged.take(limit).toList(growable: false);
    }
  }

  return basePool.take(limit).toList(growable: false);
}

/// Parses the server-resolved product objects attached to a section manifest
/// entry into [ProductEntity]s. Malformed individual records are skipped so a
/// single bad product never blanks the whole section.
List<ProductEntity> _parseManifestProducts(SectionManifestEntry entry) {
  if (entry.products.isEmpty) {
    return const <ProductEntity>[];
  }
  final List<ProductEntity> result = <ProductEntity>[];
  for (final Map<String, dynamic> raw in entry.products) {
    try {
      result.add(ProductModel.fromJson(raw).toEntity());
    } catch (_) {
      // Skip an unparseable product rather than failing the whole section.
    }
  }
  return result;
}

List<ProductEntity> _resolveDefaultProductPool(WidgetRef ref) {
  // PHASE 2C: Read from the memoized provider — computed once per Riverpod
  // build cycle instead of once per section builder call.
  return ref.watch(memoizedDefaultProductPoolProvider);
}

List<ProductEntity> _resolveFeaturedPool(WidgetRef ref) {
  // PHASE 2D: Re-use the memoized pool for featured — it already includes
  // tabHome.featuredProducts merged with homeFeaturedProductsProvider.
  // Filter to only featured/seasonal products to preserve current behaviour.
  final tabHome = ref.watch(selectedTabHomeContentProvider).asData?.value;
  final featured = ref.watch(homeFeaturedProductsProvider).asData?.value ??
      const <ProductEntity>[];
  // Only merge these two small lists; skip the full pool expansion.
  return _mergeUniqueProducts(<List<ProductEntity>>[
    tabHome?.featuredProducts ?? const <ProductEntity>[],
    featured,
  ]);
}

List<ProductEntity> _resolveTrendingPool(WidgetRef ref) {
  final tabHome = ref.watch(selectedTabHomeContentProvider).asData?.value;
  final trending = ref.watch(homeTrendingProductsProvider).asData?.value ??
      const <ProductEntity>[];
  // PHASE 2D: Merge only the two relevant lists; skip full pool re-merge.
  return _mergeUniqueProducts(<List<ProductEntity>>[
    tabHome?.trendingProducts ?? const <ProductEntity>[],
    trending,
  ]);
}

List<_PromoItem> _resolvePromoItems(WidgetRef ref, SectionManifestEntry entry) {
  // banner_source: "system" (default) → pull from live /banners API
  //               "custom"            → use inline images[] from config
  // Legacy sections without banner_source default to "system" for
  // backward compatibility (existing behaviour before this change).
  final String source = _readString(entry.config['banner_source']) ?? 'system';

  if (source == 'custom') {
    // ── Custom mode: use images[] from section config ──────────────────────
    final inlineImages = _readStringList(entry.config['images']);
    if (inlineImages.isNotEmpty) {
      return inlineImages
          .take(5)
          .map(
            (String imageUrl) => _PromoItem(
              imageUrl: imageUrl,
              linkUrl: _readString(entry.config['link_url']),
            ),
          )
          .where((item) => item.imageUrl.trim().isNotEmpty)
          .toList(growable: false);
    }
    // Also accept legacy single image_url if no images[] set yet
    if (entry.imageUrl != null && entry.imageUrl!.trim().isNotEmpty) {
      return <_PromoItem>[
        _PromoItem(
          imageUrl: entry.imageUrl!,
          linkUrl: _readString(entry.config['link_url']),
        ),
      ];
    }
    return const <_PromoItem>[];
  }

  // ── System mode (default): pull from bannerProvider ────────────────────
  final bannerAsync = ref.watch(bannerProvider);
  final banners = bannerAsync.asData?.value ?? const <BannerEntity>[];
  final sorted = List<BannerEntity>.from(banners)
    ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));

  final items = sorted
      .where((BannerEntity banner) => banner.imageUrl.trim().isNotEmpty)
      .map(
        (BannerEntity banner) => _PromoItem(
          imageUrl: banner.imageUrl,
          linkUrl: _resolveBannerTarget(banner),
        ),
      )
      .toList(growable: false);

  if (items.isNotEmpty) {
    return items;
  }

  // ── Fallback (system mode, no live banners yet): try inline config ──────
  final inlineImages = _readStringList(entry.config['images']);
  if (inlineImages.isNotEmpty) {
    return inlineImages
        .map(
          (String imageUrl) => _PromoItem(
            imageUrl: imageUrl,
            linkUrl: _readString(entry.config['link_url']),
          ),
        )
        .toList(growable: false);
  }

  if (entry.imageUrl != null && entry.imageUrl!.trim().isNotEmpty) {
    return <_PromoItem>[
      _PromoItem(
        imageUrl: entry.imageUrl!,
        linkUrl: _readString(entry.config['link_url']),
      ),
    ];
  }

  return const <_PromoItem>[];
}

String? _resolveBannerTarget(BannerEntity banner) {
  final rawValue = banner.linkValue?.trim();
  if (rawValue == null || rawValue.isEmpty) {
    return null;
  }

  switch (banner.linkType.trim().toLowerCase()) {
    case 'product':
      return '/product/$rawValue';
    case 'category':
      return '/categories/$rawValue/products';
    default:
      return rawValue.startsWith('/') ? rawValue : rawValue;
  }
}

List<ProductEntity> _mergeUniqueProducts(List<List<ProductEntity>> groups) {
  final seen = <String>{};
  final seenFamilies = <String>{};
  final merged = <ProductEntity>[];
  for (final group in groups) {
    for (final product in group) {
      if (!product.inStock) {
        continue;
      }
      // Family-based deduplication: show only one representative per family.
      // Prefer the default option if it appears later.
      if (product.productFamilyId != null &&
          product.productFamilyId!.isNotEmpty) {
        if (!seenFamilies.add(product.productFamilyId!)) {
          // Family already represented — skip sibling.
          continue;
        }
      }
      if (seen.add(product.id)) {
        merged.add(product);
      }
    }
  }
  return merged;
}

List<ProductEntity> _filterByIds(
  List<ProductEntity> products,
  List<String> ids,
) {
  if (ids.isEmpty) {
    return const <ProductEntity>[];
  }
  return products
      .where((ProductEntity product) => ids.contains(product.id))
      .toList(growable: false);
}

List<ProductEntity> _filterByTags(
  List<ProductEntity> products,
  List<String> tags,
) {
  if (tags.isEmpty) {
    return const <ProductEntity>[];
  }
  final normalizedTags = tags.map((String tag) => tag.toLowerCase()).toSet();
  return products.where((ProductEntity product) {
    return product.tags.any(
      (String tag) => normalizedTags.contains(tag.toLowerCase()),
    );
  }).toList(growable: false);
}

String? _readString(dynamic value) {
  if (value is! String) {
    return null;
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int? _readInt(dynamic value) {
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

double? _readDouble(dynamic value) {
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

bool? _readBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    if (value.trim().toLowerCase() == 'true') {
      return true;
    }
    if (value.trim().toLowerCase() == 'false') {
      return false;
    }
  }
  return null;
}

List<String> _readStringList(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .whereType<String>()
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);
}

double? _parseAspectRatio(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    final normalized = value.trim();
    if (normalized.contains(':')) {
      final parts = normalized.split(':');
      if (parts.length == 2) {
        final width = double.tryParse(parts[0]);
        final height = double.tryParse(parts[1]);
        if (width != null && height != null && height > 0) {
          return width / height;
        }
      }
    }
    return double.tryParse(normalized);
  }
  return null;
}

Color _resolveColor(String? rawValue, Color fallback) {
  final normalized = rawValue?.trim();
  if (normalized == null || normalized.isEmpty) {
    return fallback;
  }
  final cleaned = normalized.replaceFirst('#', '');
  final hex = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) {
    return fallback;
  }
  return Color(parsed);
}

List<Color> _resolveGradient(dynamic rawValue, List<Color> fallback) {
  if (rawValue is! List || rawValue.length < 2) {
    return fallback;
  }

  final first = _resolveColor(rawValue[0]?.toString(), fallback.first);
  final second = _resolveColor(rawValue[1]?.toString(), fallback.last);
  return <Color>[first, second];
}

double _screenUtilWidth(double logicalWidth) {
  final scale = ScreenUtil().scaleWidth;
  if (scale == 0) {
    return logicalWidth;
  }
  return logicalWidth / scale;
}

PhosphorIconData _categoryIconForLabel(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.contains('fruit') || normalized.contains('vegetable')) {
    return PhosphorIcons.carrot;
  }
  if (normalized.contains('dairy') || normalized.contains('egg')) {
    return PhosphorIcons.egg;
  }
  if (normalized.contains('bakery') || normalized.contains('bread')) {
    return PhosphorIcons.bread;
  }
  if (normalized.contains('drink') || normalized.contains('juice')) {
    return PhosphorIcons.drop;
  }
  if (normalized.contains('electronics')) {
    return PhosphorIcons.headphones;
  }
  if (normalized.contains('beauty')) {
    return PhosphorIcons.sparkle;
  }
  if (normalized.contains('fresh')) {
    return PhosphorIcons.appleLogo;
  }
  return PhosphorIcons.squaresFour;
}

class _ManifestFeeStrip extends StatefulWidget {
  const _ManifestFeeStrip({
    required this.containerColor,
    this.imageUrl,
  });

  final String? imageUrl;
  final Color containerColor;

  @override
  State<_ManifestFeeStrip> createState() => _ManifestFeeStripState();
}

class _ManifestFeeStripState extends State<_ManifestFeeStrip> {
  static const double _fallbackAspectRatio = 336 / 74;

  double _aspectRatio = _fallbackAspectRatio;
  String? _resolvedImageUrl;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;

  @override
  void initState() {
    super.initState();
    _syncResolvedImage();
  }

  @override
  void didUpdateWidget(covariant _ManifestFeeStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _syncResolvedImage();
    }
  }

  @override
  void dispose() {
    _detachImageStream();
    super.dispose();
  }

  void _syncResolvedImage() {
    _detachImageStream();
    final rawValue = widget.imageUrl?.trim();
    final String? resolvedValue = rawValue == null || rawValue.isEmpty
        ? null
        : (ApiConstants.resolveMediaUrl(rawValue) ?? rawValue);
    _resolvedImageUrl = rawValue == null || rawValue.isEmpty
        ? null
        : (ApiConstants.proxyMediaUrl(resolvedValue) ?? resolvedValue);
    _aspectRatio = _fallbackAspectRatio;

    if (_resolvedImageUrl == null) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final ImageProvider provider = CachedNetworkImageProvider(
      _resolvedImageUrl!,
    );
    final ImageStream stream = provider.resolve(const ImageConfiguration());

    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo image, bool _) {
        final double width = image.image.width.toDouble();
        final double height = image.image.height.toDouble();
        final double nextAspectRatio =
            height == 0 ? _fallbackAspectRatio : width / height;
        _detachImageStream();
        if (!mounted) {
          return;
        }
        setState(() {
          _aspectRatio = nextAspectRatio.isFinite && nextAspectRatio > 0
              ? nextAspectRatio
              : _fallbackAspectRatio;
        });
      },
      onError: (_, __) {
        _detachImageStream();
        if (!mounted) {
          return;
        }
        setState(() {
          _aspectRatio = _fallbackAspectRatio;
        });
      },
    );

    _imageStream = stream;
    _imageStreamListener = listener;
    stream.addListener(listener);

    if (mounted) {
      setState(() {});
    }
  }

  void _detachImageStream() {
    if (_imageStream != null && _imageStreamListener != null) {
      _imageStream!.removeListener(_imageStreamListener!);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvedImageUrl != null) {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final double safeAspectRatio =
              _aspectRatio.isFinite && _aspectRatio > 0
                  ? _aspectRatio
                  : _fallbackAspectRatio;
          final double minHeight = 60.h;
          final double maxHeight = 96.h;
          final double targetHeight =
              (width / safeAspectRatio).clamp(minHeight, maxHeight).toDouble();

          return SizedBox(
            height: targetHeight,
            width: double.infinity,
            child: ColoredBox(
              color: widget.containerColor,
              child: AppImage(
                imageUrl: _resolvedImageUrl!,
                memCacheWidth: 1200,
                memCacheHeight: 333,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
                placeholder: ColoredBox(
                  color: widget.containerColor,
                  child: const SizedBox.expand(),
                ),
                errorWidget: const _FeeStripFallback(),
              ),
            ),
          );
        },
      );
    }

    return const _FeeStripFallback();
  }
}

class _FeeStripFallback extends StatelessWidget {
  const _FeeStripFallback();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, 2.h),
      child: Container(
        height: 42.h,
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1C9A38),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          children: <Widget>[
            PhosphorIcon(
              PhosphorIcons.ticketFill,
              color: Colors.white,
              size: 17.sp,
            ),
            Gap(8.w),
            Expanded(
              child: Text(
                '₹0 Platform Fee • ₹0 Delivery Fee',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManifestCategorySection extends StatelessWidget {
  const _ManifestCategorySection({
    required this.title,
    required this.subtitle,
    required this.header,
    required this.items,
    required this.layout,
  });

  final String? title;
  final String? subtitle;
  final SectionHeaderConfig header;
  final List<_CategoryRailItem> items;
  final CategorySectionLayoutConfig layout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (header.showText &&
            ((title?.trim().isNotEmpty ?? false) ||
                (subtitle?.trim().isNotEmpty ?? false)))
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
            child: _categorySectionHeading(title, subtitle),
          ),
        if (header.showGraphic) _ManifestGraphicSectionHeader(header: header),
        _ManifestCategoryRail(
          items: items,
          iconSize: layout.iconSize,
          gap: layout.gap,
          rowGap: layout.rowGap,
          showLabels: layout.showLabels,
          isGrid: layout.isGrid,
        ),
      ],
    );
  }
}

Widget _categorySectionHeading(String? title, String? subtitle) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      if (title != null && title.trim().isNotEmpty)
        Text(
          title,
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF141414),
          ),
        ),
      if (subtitle != null && subtitle.trim().isNotEmpty) ...<Widget>[
        Gap(4.h),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12.sp, color: const Color(0xFF626262)),
        ),
      ],
    ],
  );
}

class _ManifestCategoryRail extends StatelessWidget {
  const _ManifestCategoryRail({
    required this.items,
    required this.iconSize,
    required this.gap,
    required this.rowGap,
    required this.showLabels,
    required this.isGrid,
  });

  final List<_CategoryRailItem> items;
  final double iconSize;
  final double gap;
  final double rowGap;
  final bool showLabels;
  final bool isGrid;

  @override
  Widget build(BuildContext context) {
    if (isGrid) {
      return _buildGrid(context);
    }
    final double tileWidth = (iconSize + 18).clamp(82, 120).toDouble();
    final double boxRadius = (iconSize * 0.34).clamp(16, 26).toDouble();
    final double artworkRadius = (boxRadius - 2).clamp(14, 24).toDouble();
    final double railHeight = showLabels ? iconSize + 40 : iconSize + 12;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 2.h),
      child: SizedBox(
        height: railHeight.h,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          itemExtentBuilder: (int index, _) => _horizontalSectionExtent(
            index,
            items.length,
            tileWidth.w,
            gap.w,
          ),
          itemBuilder: (BuildContext context, int index) {
            final item = items[index];
            return Align(
              alignment: Alignment.centerLeft,
              child: _categoryRailTile(
                context,
                item,
                tileWidth.w,
                boxRadius,
                artworkRadius,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final double boxRadius = (iconSize * 0.34).clamp(16, 26).toDouble();
    final double artworkRadius = (boxRadius - 2).clamp(14, 24).toDouble();
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 2.h),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double spacing = gap.w;
          final double tileWidth = (constraints.maxWidth - (spacing * 3)) / 4;
          return Wrap(
            spacing: spacing,
            runSpacing: rowGap.h,
            children: items
                .map(
                  (_CategoryRailItem item) => SizedBox(
                    width: tileWidth,
                    child: _categoryRailTile(
                      context,
                      item,
                      tileWidth,
                      boxRadius,
                      artworkRadius,
                    ),
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
    );
  }

  Widget _categoryRailTile(
    BuildContext context,
    _CategoryRailItem item,
    double tileWidth,
    double boxRadius,
    double artworkRadius,
  ) {
    return GestureDetector(
      onTap: item.categoryId == null
          ? null
          : () => context.push('/categories/${item.categoryId}/products'),
      child: SizedBox(
        width: tileWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: iconSize.w,
              height: iconSize.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(boxRadius.r),
                border: Border.all(color: const Color(0xFFF0F0F0), width: 1),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 0,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(artworkRadius.r),
                child: _CategoryArtwork(
                    label: item.label, imageUrl: item.imageUrl),
              ),
            ),
            if (showLabels) ...<Widget>[
              Gap(8.h),
              Text(
                item.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall.copyWith(
                  color: const Color(0xFF131313),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryArtwork extends StatelessWidget {
  const _CategoryArtwork({
    required this.label,
    required this.imageUrl,
  });

  final String label;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = ApiConstants.resolveMediaUrl(imageUrl);
    final optimizedImage = ApiConstants.optimizedMedia(
      resolvedImageUrl,
      profile: CustomerImageProfile.categoryTile,
    );

    if (resolvedImageUrl == null || resolvedImageUrl.isEmpty) {
      return ColoredBox(
        color: const Color(0xFFF3F6E7),
        child: Center(
          child: PhosphorIcon(
            _categoryIconForLabel(label),
            size: 24.sp,
            color: const Color(0xFF69705E),
          ),
        ),
      );
    }

    return AppImage(
      imageUrl: optimizedImage.url ?? resolvedImageUrl,
      fit: BoxFit.cover,
      memCacheWidth: optimizedImage.memCacheWidth,
      memCacheHeight: optimizedImage.memCacheHeight,
      filterQuality: FilterQuality.high,
      placeholder: const ColoredBox(
        color: Color(0xFFF3F6E7),
        child: SizedBox.expand(),
      ),
      errorWidget: ColoredBox(
        color: const Color(0xFFF3F6E7),
        child: Center(
          child: PhosphorIcon(
            _categoryIconForLabel(label),
            size: 24.sp,
            color: const Color(0xFF69705E),
          ),
        ),
      ),
    );
  }
}

class _CategoryRailItem {
  const _CategoryRailItem({
    required this.label,
    this.imageUrl,
    this.categoryId,
  });

  final String label;
  final String? imageUrl;
  final String? categoryId;
}

class _ManifestProductGridSection extends StatelessWidget {
  const _ManifestProductGridSection({
    required this.title,
    required this.products,
    required this.columns,
    required this.header,
    this.subtitle,
    this.variant = ProductCardVariant.quickCommerceCompact,
  });

  final String title;
  final String? subtitle;
  final List<ProductEntity> products;
  final int columns;
  final SectionHeaderConfig header;
  final ProductCardVariant variant;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (header.showText)
          Padding(
            padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 0),
            child: _productHeading(title, subtitle, variant),
          ),
        if (header.showGraphic) _ManifestGraphicSectionHeader(header: header),
        Gap(10.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final gap =
                  variant == ProductCardVariant.premiumFresh ? 12.w : 10.w;
              final minItemWidth = 104.w;
              final maxColumnsForWidth =
                  ((constraints.maxWidth + gap) / (minItemWidth + gap))
                      .floor()
                      .clamp(1, columns);
              final effectiveColumns = maxColumnsForWidth;
              final itemWidth =
                  (constraints.maxWidth - (gap * (effectiveColumns - 1))) /
                      effectiveColumns;
              final cardWidth = _screenUtilWidth(itemWidth);

              return Wrap(
                spacing: gap,
                runSpacing:
                    variant == ProductCardVariant.premiumFresh ? 16.h : 12.h,
                children: products
                    .map(
                      (ProductEntity product) => SizedBox(
                        width: itemWidth,
                        child: ProductCard(
                          product: product,
                          width: cardWidth,
                          style: ProductCardStyle.grid,
                          variant: variant,
                          showWishlist: true,
                          onTap: () => context.push('/product/${product.id}'),
                          onOptionsTap: product.hasMultipleOptions
                              ? () => showProductOptionsSheet(context, product)
                              : null,
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ManifestHorizontalProductSection extends StatelessWidget {
  const _ManifestHorizontalProductSection({
    required this.title,
    required this.products,
    this.header = const SectionHeaderConfig(
      style: SectionHeaderStyle.text,
      imageUrl: null,
      visible: true,
      aspectRatio: SectionHeaderConfig.canonicalAspectRatio,
      borderRadius: 14,
      horizontalMargin: 16,
      bottomSpacing: 12,
      linkUrl: null,
    ),
    this.subtitle,
    this.accentColor,
    this.variant = ProductCardVariant.quickCommerceCompact,
  });

  final String title;
  final String? subtitle;
  final List<ProductEntity> products;
  final SectionHeaderConfig header;
  final Color? accentColor;
  final ProductCardVariant variant;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (header.showText)
          Padding(
            padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 0),
            child: _productHeading(
              title,
              subtitle,
              variant,
              accentColor: accentColor,
            ),
          ),
        if (header.showGraphic) _ManifestGraphicSectionHeader(header: header),
        Gap(10.h),
        SizedBox(
          height: variant == ProductCardVariant.premiumFresh
              ? 320.h * MediaQuery.textScalerOf(context).scale(1)
              : 246.h,
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: products.length,
            itemExtentBuilder: (int index, _) => _horizontalSectionExtent(
              index,
              products.length,
              variant == ProductCardVariant.premiumFresh ? 240.w : 132.w,
              variant == ProductCardVariant.premiumFresh ? 24.w : 10.w,
            ),
            itemBuilder: (BuildContext context, int index) {
              final product = products[index];
              return Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: variant == ProductCardVariant.premiumFresh
                      ? 240.w
                      : 132.w,
                  child: ProductCard(
                    product: product,
                    width:
                        variant == ProductCardVariant.premiumFresh ? 240 : 132,
                    style: ProductCardStyle.scroll,
                    variant: variant,
                    showWishlist: true,
                    onTap: () => context.push('/product/${product.id}'),
                    onOptionsTap: product.hasMultipleOptions
                        ? () => showProductOptionsSheet(context, product)
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ManifestGraphicSectionHeader extends StatelessWidget {
  const _ManifestGraphicSectionHeader({required this.header});

  final SectionHeaderConfig header;

  @override
  Widget build(BuildContext context) {
    final String imageUrl =
        ApiConstants.resolveMediaUrl(header.imageUrl) ?? header.imageUrl ?? '';
    final VoidCallback? onTap = header.linkUrl == null
        ? null
        : () => _handleManifestLinkTap(context, header.linkUrl!);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        header.horizontalMargin.w,
        12.h,
        header.horizontalMargin.w,
        header.bottomSpacing.h,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(header.borderRadius.r),
          child: AspectRatio(
            aspectRatio: header.aspectRatio,
            child: AppImage(
              imageUrl: imageUrl,
              // An exact 1080×300 image has no crop. `contain` is the safe
              // default for uploads that are slightly off-ratio, preserving
              // the complete campaign composition rather than stretching it.
              fit: BoxFit.contain,
              alignment: Alignment.center,
              memCacheWidth: 1080,
              memCacheHeight: 300,
              filterQuality: FilterQuality.high,
              placeholder: const ColoredBox(
                color: Color(0xFFF8FAFC),
                child: SizedBox.expand(),
              ),
              errorWidget: const ColoredBox(
                color: Color(0xFFF8FAFC),
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _productHeading(
  String title,
  String? subtitle,
  ProductCardVariant variant, {
  Color? accentColor,
}) {
  if (variant != ProductCardVariant.premiumFresh) {
    return _ManifestSectionHeader(title: title, accentColor: accentColor);
  }
  return Padding(
    padding: EdgeInsets.only(top: 12.h, bottom: 6.h),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 21.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: -.35,
            color: const Color(0xFF141414),
          ),
        ),
        if (subtitle != null && subtitle.trim().isNotEmpty) ...[
          Gap(5.h),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 14.sp,
              height: 1.4,
              color: const Color(0xFF626262),
            ),
          ),
        ],
      ],
    ),
  );
}

class _ManifestSectionHeader extends StatelessWidget {
  const _ManifestSectionHeader({
    required this.title,
    this.accentColor,
  });

  final String title;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    if (accentColor == null) {
      return Text(
        title,
        style: AppTextStyles.h2.copyWith(
          fontSize: 18.sp,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      );
    }

    final words = title.split(' ');
    if (words.length < 2) {
      return Text(
        title,
        style: AppTextStyles.h2.copyWith(
          fontSize: 18.sp,
          fontWeight: FontWeight.w800,
          color: accentColor,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: AppTextStyles.h2.copyWith(
          fontSize: 18.sp,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
        children: <InlineSpan>[
          TextSpan(text: '${words.sublist(0, words.length - 1).join(' ')} '),
          TextSpan(
            text: words.last,
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManifestPromoCarousel extends StatefulWidget {
  const _ManifestPromoCarousel({
    required this.items,
    required this.borderRadius,
    required this.aspectRatio,
    required this.autoScroll,
    required this.autoScrollSpeedMs,
  });

  final List<_PromoItem> items;
  final double borderRadius;
  final double aspectRatio;
  final bool autoScroll;
  final int autoScrollSpeedMs;

  @override
  State<_ManifestPromoCarousel> createState() => _ManifestPromoCarouselState();
}

class _ManifestPromoCarouselState extends State<_ManifestPromoCarousel> {
  late final PageController _controller;
  Timer? _timer;
  // PHASE 4D: Replace local _page int (setState per tick) with ValueNotifier.
  // Only the _PromoPageDots widget rebuilds when the page changes — the
  // PageView and its card items are untouched.
  late final ValueNotifier<int> _pageNotifier;

  @override
  void initState() {
    super.initState();
    _pageNotifier = ValueNotifier<int>(0);
    _controller = PageController(viewportFraction: 0.92);
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(covariant _ManifestPromoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length ||
        oldWidget.autoScroll != widget.autoScroll ||
        oldWidget.autoScrollSpeedMs != widget.autoScrollSpeedMs) {
      _timer?.cancel();
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    if (!widget.autoScroll || widget.items.length <= 1) {
      return;
    }
    _timer = Timer.periodic(
      Duration(milliseconds: widget.autoScrollSpeedMs.clamp(1500, 10000)),
      (_) {
        if (!mounted || !_controller.hasClients) {
          return;
        }
        final next = (_pageNotifier.value + 1) % widget.items.length;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageNotifier.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(
          height: 186.h,
          child: PageView.builder(
            controller: _controller,
            padEnds: true,
            itemCount: widget.items.length,
            onPageChanged: (int value) {
              // PHASE 4D: ValueNotifier update instead of setState — only
              // _PromoPageDots rebuilds, not the full carousel Column.
              _pageNotifier.value = value;
            },
            itemBuilder: (BuildContext context, int index) {
              final item = widget.items[index];
              return CustomBannerSection(
                imageUrl: item.imageUrl,
                linkUrl: item.linkUrl,
                borderRadius: widget.borderRadius,
                aspectRatio: widget.aspectRatio,
              );
            },
          ),
        ),
        if (widget.items.length > 1) ...<Widget>[
          Gap(6.h),
          // PHASE 4D: Isolated dots widget — only this rebuilds on page change.
          _PromoPageDots(
            count: widget.items.length,
            pageNotifier: _pageNotifier,
          ),
        ],
      ],
    );
  }
}

/// Isolated page indicator for _ManifestPromoCarousel.
/// Listens to the ValueNotifier and rebuilds only the dots row.
class _PromoPageDots extends StatelessWidget {
  const _PromoPageDots({
    required this.count,
    required this.pageNotifier,
  });

  final int count;
  final ValueNotifier<int> pageNotifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: pageNotifier,
      builder: (BuildContext context, int page, Widget? _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(
            count,
            (int index) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: index == page ? 16.w : 6.w,
              height: 6.h,
              margin: EdgeInsets.symmetric(horizontal: 3.w),
              decoration: BoxDecoration(
                color: index == page
                    ? AppColors.warmOrangeDark
                    : const Color(0xFFD5D5D5),
                borderRadius: BorderRadius.circular(999.r),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ManifestBankOffersRow extends StatelessWidget {
  const _ManifestBankOffersRow({
    required this.items,
  });

  final List<_PromoItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 6.h, 0, 2.h),
      child: SizedBox(
        height: 74.h,
        child: ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          itemExtentBuilder: (int index, _) => _horizontalSectionExtent(
            index,
            items.length,
            336.w,
            14.w,
          ),
          itemBuilder: (BuildContext context, int index) {
            final item = items[index];
            final resolvedImage = ApiConstants.proxyMediaUrl(
                  ApiConstants.resolveMediaUrl(item.imageUrl) ?? item.imageUrl,
                ) ??
                ApiConstants.resolveMediaUrl(item.imageUrl) ??
                item.imageUrl;
            final VoidCallback? handleTap = item.linkUrl == null ||
                    item.linkUrl!.trim().isEmpty
                ? null
                : () => _handleManifestLinkTap(context, item.linkUrl!.trim());

            return Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: handleTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.r),
                  child: SizedBox(
                    width: 336.w,
                    height: 74.h,
                    child: AppImage(
                      imageUrl: resolvedImage,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      memCacheWidth: 1440,
                      memCacheHeight: 317,
                      filterQuality: FilterQuality.high,
                      placeholder: const ColoredBox(
                        color: Color(0xFFF2F8FF),
                        child: SizedBox.expand(),
                      ),
                      errorWidget: const ColoredBox(
                        color: Color(0xFFF2F8FF),
                        child: SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Arched Product Showcase ────────────────────────────────────────────

Widget _buildArchedProductShowcase(
  SectionManifestEntry entry,
  RemoteTheme theme,
  WidgetRef ref,
) {
  final products = _resolveProducts(ref, entry, fallbackLimit: 10);
  final categoriesAsync = ref.watch(categoryCollectionProvider);
  final categories = categoriesAsync.asData?.value ?? const <CategoryEntity>[];
  final containerColor = _resolveColor(
    entry.containerColor,
    const Color(0xFFFDE7C4),
  );
  final cardShape = entry.cardShape ?? 'arch';
  final archHeight = entry.archHeight ?? 14.0;
  final cornerRadius = entry.cornerRadius ?? 24.0;

  final bgGradient = entry.bgGradient;
  final bgGradientColors = bgGradient.length >= 2
      ? bgGradient
          .map((hex) => _resolveColor(hex, containerColor))
          .toList(growable: false)
      : null;

  final boxGradient = entry.boxGradient;
  final boxGradientColors = boxGradient.length >= 2
      ? boxGradient
          .map((hex) => _resolveColor(hex, containerColor))
          .toList(growable: false)
      : null;
  final categoryStripItems = entry.archedCategoryStripItems.map((item) {
    final link = _readString(item['link']);
    final resolvedLink = _resolveArchedCategoryLink(link, categories);
    if (resolvedLink == null || resolvedLink == link) {
      return item;
    }

    return <String, dynamic>{...item, 'link': resolvedLink};
  }).toList(growable: false);

  return _ManifestArchedProductSection(
    title: entry.title ?? 'Top Picks',
    showTitle: entry.showTitle,
    titleColor: _resolveColor(entry.titleColor, const Color(0xFF1A1A1A)),
    bannerEnabled: entry.archedBannerEnabled,
    bannerContentSource: entry.archedBannerContentSource,
    bannerLottieUrl: entry.archedBannerLottieUrl,
    bannerImageUrl: entry.archedBannerImageUrl,
    bannerHeight: entry.archedBannerHeight,
    bannerGradient: entry.archedBannerGradient.length >= 2
        ? entry.archedBannerGradient
            .map((hex) => _resolveColor(hex, const Color(0xFFE8F5E9)))
            .toList(growable: false)
        : null,
    categoryStripEnabled: entry.archedCategoryStripEnabled,
    categoryStripItems: categoryStripItems,
    categoryStripIconSize: entry.archedCategoryStripIconSize,
    categoryStripShowLabels: entry.archedCategoryStripShowLabels,
    products: products,
    productLayout: entry.productLayout,
    backgroundColor: containerColor,
    bgGradientColors: bgGradientColors,
    cardShape: cardShape,
    archHeight: archHeight,
    cornerRadius: cornerRadius,
    boxGradientColors: boxGradientColors,
  );
}

String? _resolveArchedCategoryLink(
  String? target,
  List<CategoryEntity> categories,
) {
  final trimmed = target?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
    return trimmed;
  }

  final normalizedTarget = trimmed.startsWith('/') ? trimmed : '/$trimmed';
  if (normalizedTarget.contains('/products')) {
    return normalizedTarget;
  }

  final match = RegExp(r'^/categories/([^/]+)$').firstMatch(normalizedTarget);
  if (match == null) {
    return normalizedTarget;
  }

  final rawToken = match.group(1);
  if (rawToken == null || rawToken.isEmpty) {
    return normalizedTarget;
  }

  final token = _normalizeCategoryLookupToken(rawToken);
  CategoryEntity? fallbackMatch;

  for (final category in categories) {
    final nameToken = _normalizeCategoryLookupToken(category.name);
    if (nameToken == token || category.id == rawToken) {
      return '/categories/${category.id}/products';
    }

    if (fallbackMatch == null &&
        nameToken.contains(token) &&
        category.isActive) {
      fallbackMatch = category;
    }
  }

  if (fallbackMatch != null) {
    return '/categories/${fallbackMatch.id}/products';
  }

  return normalizedTarget;
}

String _normalizeCategoryLookupToken(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

class _ManifestArchedProductSection extends StatelessWidget {
  const _ManifestArchedProductSection({
    required this.title,
    required this.showTitle,
    required this.titleColor,
    required this.bannerEnabled,
    required this.bannerContentSource,
    required this.bannerHeight,
    required this.categoryStripEnabled,
    required this.categoryStripItems,
    required this.categoryStripIconSize,
    required this.categoryStripShowLabels,
    required this.products,
    required this.productLayout,
    required this.backgroundColor,
    this.bannerLottieUrl,
    this.bannerImageUrl,
    this.bannerGradient,
    this.bgGradientColors,
    this.cardShape = 'arch',
    this.archHeight = 14.0,
    this.cornerRadius = 24.0,
    this.boxGradientColors,
  });

  final String title;
  final bool showTitle;
  final Color titleColor;
  final bool bannerEnabled;
  final String bannerContentSource;
  final String? bannerLottieUrl;
  final String? bannerImageUrl;
  final double bannerHeight;
  final List<Color>? bannerGradient;
  final bool categoryStripEnabled;
  final List<Map<String, dynamic>> categoryStripItems;
  final double categoryStripIconSize;
  final bool categoryStripShowLabels;
  final List<ProductEntity> products;
  final String productLayout;
  final Color backgroundColor;
  final List<Color>? bgGradientColors;
  final String cardShape;
  final double archHeight;
  final double cornerRadius;
  final List<Color>? boxGradientColors;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showTitle)
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 10.h),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
          ),
        if (bannerEnabled) _buildBannerZone(context),
        if (categoryStripEnabled && categoryStripItems.isNotEmpty)
          _buildCategoryStrip(context),
        if (products.isNotEmpty)
          buildArchedProductLayout(
            productLayout,
            ArchedLayoutParams(
              products: products,
              backgroundColor: backgroundColor,
              cardShape: cardShape,
              archHeight: archHeight,
              cornerRadius: cornerRadius,
              boxGradientColors: boxGradientColors,
            ),
          ),
        Gap(12.h),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFDFB8),
              elevation: 0,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const Gap(4),
                PhosphorIcon(
                  PhosphorIcons.caretRightBold,
                  size: 14,
                  color: Colors.black87,
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: bgGradientColors != null
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: bgGradientColors!,
                )
              : null,
        ),
        child: content,
      ),
    );
  }

  Widget _buildBannerZone(BuildContext context) {
    final gradientColors = bannerGradient ??
        <Color>[
          const Color(0xFFE8F5E9),
          const Color(0xFFC8E6C9),
        ];

    if (bannerContentSource == 'lottie' &&
        bannerLottieUrl != null &&
        bannerLottieUrl!.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.only(bottom: 10.h),
        child: AnimatedBannerSection(
          // No local fallback — only render remote lottie from dashboard.
          assetPath: '',
          height: bannerHeight,
          bannerTheme: BannerAnimationTheme(
            imageUrl: null,
            lottieUrl: bannerLottieUrl,
            backgroundGradient: gradientColors,
            containerColor: gradientColors.first,
          ),
          feeStripTheme: const FeeStripTheme(
            imageUrl: null,
            visible: false,
          ),
        ),
      );
    }

    if (bannerContentSource == 'image' &&
        bannerImageUrl != null &&
        bannerImageUrl!.isNotEmpty) {
      final resolvedUrl = ApiConstants.resolveMediaUrl(bannerImageUrl);
      return Padding(
        padding: EdgeInsets.only(bottom: 10.h),
        child: Container(
          height: bannerHeight.h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16.r),
          ),
          clipBehavior: Clip.antiAlias,
          child: resolvedUrl != null
              ? AppImage(
                  imageUrl: resolvedUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 800,
                  memCacheHeight: 360,
                )
              : null,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Container(
        height: bannerHeight.h,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
        ),
      ),
    );
  }

  Widget _buildCategoryStrip(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: SizedBox(
        height: categoryStripShowLabels
            ? categoryStripIconSize.h + 24.h
            : categoryStripIconSize.h,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: categoryStripItems.length,
          itemExtentBuilder: (int index, _) => _horizontalSectionExtent(
            index,
            categoryStripItems.length,
            (categoryStripIconSize + 8).w,
            12.w,
          ),
          itemBuilder: (BuildContext context, int index) {
            final item = categoryStripItems[index];
            final label = _readString(item['label']) ?? '';
            final imageUrl = _readString(item['image_url']);
            final link = _readString(item['link']);

            return Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: link != null && link.isNotEmpty
                    ? () => _handleManifestLinkTap(context, link)
                    : null,
                child: SizedBox(
                  width: categoryStripIconSize.w + 8.w,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: categoryStripIconSize.w,
                        height: categoryStripIconSize.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade200,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? AppImage(
                                imageUrl:
                                    ApiConstants.resolveMediaUrl(imageUrl) ??
                                        '',
                                fit: BoxFit.cover,
                                memCacheWidth: 160,
                                memCacheHeight: 160,
                                errorWidget: PhosphorIcon(
                                  PhosphorIcons.packageDuotone,
                                  size: 24.sp,
                                  color: Colors.grey,
                                ),
                              )
                            : PhosphorIcon(
                                PhosphorIcons.packageDuotone,
                                size: 24.sp,
                                color: Colors.grey,
                              ),
                      ),
                      if (categoryStripShowLabels && label.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 4.h),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PromoItem {
  const _PromoItem({
    required this.imageUrl,
    required this.linkUrl,
  });

  final String imageUrl;
  final String? linkUrl;
}

Future<void> _handleManifestLinkTap(BuildContext context, String target) async {
  final uri = Uri.tryParse(target);
  if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }

  if (!context.mounted) {
    return;
  }

  final container = ProviderScope.containerOf(context, listen: false);
  final categoriesAsync = container.read(categoryCollectionProvider);
  final categories = categoriesAsync.asData?.value ?? const <CategoryEntity>[];
  final resolvedTarget =
      _resolveArchedCategoryLink(target, categories) ?? target;

  context.push(
    resolvedTarget.startsWith('/') ? resolvedTarget : '/$resolvedTarget',
  );
}
