import 'dart:async';
import 'dart:math' as math;

import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/layout/responsive_breakpoints.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';

class SeasonalDealMosaic extends StatelessWidget {
  const SeasonalDealMosaic({
    required this.products,
    this.heroCandidates,
    this.mosaicTheme,
    this.layoutVariant = 'hero_plus_four',
    super.key,
  });

  final List<ProductEntity> products;
  final List<ProductEntity>? heroCandidates;
  final SeasonalMosaicTheme? mosaicTheme;
  final String layoutVariant;

  @override
  Widget build(BuildContext context) {
    final tiles = _buildTiles(products, mosaicTheme);
    final heroProducts = _buildHeroProducts(heroCandidates ?? products);
    final miniTiles = _buildMiniAssetTiles(products, mosaicTheme);
    if (tiles.isEmpty || miniTiles.isEmpty) {
      return const SizedBox.shrink();
    }

    late final Widget content;
    switch (layoutVariant) {
      case 'two_by_three':
        content = _buildMiniTileGrid(
          miniTiles,
          crossAxisCount: 3,
          tileCount: 6,
          childAspectRatio: 0.78,
        );
        break;
      case 'single_hero':
        content = Padding(
          padding: EdgeInsets.symmetric(horizontal: 5.w),
          child: AspectRatio(
            aspectRatio: 1.95,
            child: _HeroSeasonalDealTile(
              product: heroProducts.first,
              title: tiles[0].title,
              gradient: tiles[0].gradient,
              heroTileTheme: mosaicTheme?.heroTile,
              action: mosaicTheme?.heroTile.action,
            ),
          ),
        );
        break;
      case 'two_by_two':
        content = _buildMiniTileGrid(
          miniTiles,
          crossAxisCount: 2,
          tileCount: 4,
          childAspectRatio: 1.05,
        );
        break;
      case 'stacked_banners':
        content = Padding(
          padding: EdgeInsets.symmetric(horizontal: 5.w),
          child: Column(
            children: List<Widget>.generate(3, (int index) {
              final tile = miniTiles[index % miniTiles.length];
              return Padding(
                padding: EdgeInsets.only(bottom: index == 2 ? 0 : 8.h),
                child: AspectRatio(
                  aspectRatio: 2.35,
                  child: _AssetMiniDealTile(
                    product: tile.product,
                    assetPath: tile.assetPath,
                    imageUrl: tile.imageUrl,
                    title: tile.title,
                    gradient: tile.gradient,
                    action: tile.action,
                  ),
                ),
              );
            }),
          ),
        );
        break;
      case 'hero_plus_four':
      default:
        if (miniTiles.length < 4) {
          return const SizedBox.shrink();
        }
        content = Padding(
          padding: EdgeInsets.symmetric(horizontal: 5.w),
          child: AspectRatio(
            // The phone ratio is intentionally tall for touch-friendly
            // imagery, but it becomes an oversized billboard on desktop.
            // A wide storefront gets a dense merchandising band instead.
            aspectRatio: MediaQuery.sizeOf(context).width >=
                    ResponsiveBreakpoints.desktop
                ? 3.55
                : MediaQuery.sizeOf(context).width >=
                        ResponsiveBreakpoints.tablet
                    ? 2.2
                    : 1.48,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = MediaQuery.sizeOf(context).width >=
                    ResponsiveBreakpoints.desktop;
                final gap = isDesktop ? 12.w : 8.w;
                final smallGap = gap;
                final leftWidth =
                    constraints.maxWidth * (isDesktop ? 0.40 : 0.36);
                final rightWidth = constraints.maxWidth - leftWidth - gap;
                final tileHeight = (constraints.maxHeight - smallGap) / 2;
                final tileWidth = (rightWidth - smallGap) / 2;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      width: leftWidth,
                      child: _HeroSeasonalDealTile(
                        product: heroProducts.first,
                        title: tiles[0].title,
                        gradient: tiles[0].gradient,
                        heroTileTheme: mosaicTheme?.heroTile,
                        action: mosaicTheme?.heroTile.action,
                      ),
                    ),
                    SizedBox(width: gap),
                    SizedBox(
                      width: rightWidth,
                      child: Column(
                        children: <Widget>[
                          SizedBox(
                            height: tileHeight,
                            child: Row(
                              children: <Widget>[
                                SizedBox(
                                  width: tileWidth,
                                  child: _AssetMiniDealTile(
                                    product: miniTiles[0].product,
                                    assetPath: miniTiles[0].assetPath,
                                    imageUrl: miniTiles[0].imageUrl,
                                    title: miniTiles[0].title,
                                    gradient: miniTiles[0].gradient,
                                    action: miniTiles[0].action,
                                  ),
                                ),
                                SizedBox(width: smallGap),
                                SizedBox(
                                  width: tileWidth,
                                  child: _AssetMiniDealTile(
                                    product: miniTiles[1].product,
                                    assetPath: miniTiles[1].assetPath,
                                    imageUrl: miniTiles[1].imageUrl,
                                    title: miniTiles[1].title,
                                    gradient: miniTiles[1].gradient,
                                    action: miniTiles[1].action,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: smallGap),
                          SizedBox(
                            height: tileHeight,
                            child: Row(
                              children: <Widget>[
                                SizedBox(
                                  width: tileWidth,
                                  child: _AssetMiniDealTile(
                                    product: miniTiles[2].product,
                                    assetPath: miniTiles[2].assetPath,
                                    imageUrl: miniTiles[2].imageUrl,
                                    title: miniTiles[2].title,
                                    gradient: miniTiles[2].gradient,
                                    action: miniTiles[2].action,
                                  ),
                                ),
                                SizedBox(width: smallGap),
                                SizedBox(
                                  width: tileWidth,
                                  child: _AssetMiniDealTile(
                                    product: miniTiles[3].product,
                                    assetPath: miniTiles[3].assetPath,
                                    imageUrl: miniTiles[3].imageUrl,
                                    title: miniTiles[3].title,
                                    gradient: miniTiles[3].gradient,
                                    action: miniTiles[3].action,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
        break;
    }

    final surfaceColor = mosaicTheme?.containerColor ??
        SeasonalMosaicTheme.defaults().containerColor;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28.r),
          bottomRight: Radius.circular(28.r),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, 4.h, 0, 4.h),
        child: content,
      ),
    );
  }

  Widget _buildMiniTileGrid(
    List<_MiniAssetTileSpec> miniTiles, {
    required int crossAxisCount,
    required int tileCount,
    required double childAspectRatio,
  }) {
    final spacing = 8.w;
    final runSpacing = 8.h;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5.w),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalSpacing = spacing * (crossAxisCount - 1);
          final itemWidth =
              (constraints.maxWidth - totalSpacing) / crossAxisCount;
          final itemHeight = itemWidth / childAspectRatio;

          return Wrap(
            spacing: spacing,
            runSpacing: runSpacing,
            children: List<Widget>.generate(tileCount, (int index) {
              final tile = miniTiles[index % miniTiles.length];
              return SizedBox(
                width: itemWidth,
                height: itemHeight,
                child: _AssetMiniDealTile(
                  product: tile.product,
                  assetPath: tile.assetPath,
                  imageUrl: tile.imageUrl,
                  title: tile.title,
                  gradient: tile.gradient,
                  action: tile.action,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _HeroSeasonalDealTile extends StatelessWidget {
  const _HeroSeasonalDealTile({
    required this.product,
    required this.title,
    required this.gradient,
    this.heroTileTheme,
    this.action,
  });

  final ProductEntity product;
  final String title;
  final List<Color> gradient;
  final HeroTileTheme? heroTileTheme;
  final MosaicTileAction? action;

  @override
  Widget build(BuildContext context) {
    final defaultHeroTileTheme = HeroTileTheme.defaults();
    final resolvedHeroTileTheme = heroTileTheme ?? defaultHeroTileTheme;
    final borderRadius = BorderRadius.circular(28.r);

    // When the dashboard has a custom uploaded image_url, show it as a single
    // centered image (no duplication, no rotation). Only use the animated
    // 3-product-artwork stack for auto-picked catalog images.
    final String? configuredImageUrl =
        resolvedHeroTileTheme.imageUrl?.trim().isNotEmpty == true
            ? resolvedHeroTileTheme.imageUrl
            : null;

    final BoxDecoration tileBg = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: gradient,
      ),
      borderRadius: borderRadius,
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x12000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    );

    // ── Custom uploaded image, full-bleed: a complete pre-designed banner
    // (its own caption/branding already baked into the artwork) meant to
    // fill the entire tile edge-to-edge — no reserved title gap, no product-
    // photo treatment. Title/badge only render if the admin actually set
    // them (an admin relying on the banner's own baked-in text leaves both
    // empty, per the "explicit empty means show nothing" rule upstream).
    if (configuredImageUrl != null &&
        resolvedHeroTileTheme.imageFit == 'cover') {
      final bool hasTitle = title.trim().isNotEmpty;
      final bool hasBadge = resolvedHeroTileTheme.badgeText.trim().isNotEmpty;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => resolveMosaicTap(context, action, product.id),
          borderRadius: borderRadius,
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Ink(
              decoration: tileBg,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final burstSize = constraints.maxWidth * 0.54;
                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: <Widget>[
                      Positioned.fill(
                        child: AppImage(
                          imageUrl: configuredImageUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 450,
                          memCacheHeight: 836,
                          filterQuality: FilterQuality.high,
                          errorWidget: const SizedBox.shrink(),
                        ),
                      ),
                      if (hasTitle)
                        Positioned(
                          top: constraints.maxHeight * 0.055,
                          left: constraints.maxWidth * 0.07,
                          right: constraints.maxWidth * 0.07,
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            style: AppTextStyles.h2.copyWith(
                              color: Colors.white,
                              fontSize: 19.sp,
                              fontWeight: FontWeight.w900,
                              height: 1.02,
                              letterSpacing: -0.65,
                              shadows: const <Shadow>[
                                Shadow(
                                  color: Color(0x18000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (hasBadge)
                        Positioned(
                          right: constraints.maxWidth * 0.09,
                          bottom: constraints.maxHeight * 0.07,
                          child: Transform.rotate(
                            angle: -0.04,
                            child: _DealBurstBadge(
                              size: burstSize,
                              text: resolvedHeroTileTheme.badgeText,
                              gradient: resolvedHeroTileTheme.badgeGradient,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    // ── Custom uploaded image, product-photo mode: floats over the lower
    // ~78% of the tile with room left above it for the title. This is the
    // original behavior, kept for any hero tile that hasn't opted into
    // full-bleed 'cover' — always show its title/badge as before.
    if (configuredImageUrl != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => resolveMosaicTap(context, action, product.id),
          borderRadius: borderRadius,
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Ink(
              decoration: tileBg,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final burstSize = constraints.maxWidth * 0.54;
                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: <Widget>[
                      // Single image — centred, fills the lower 75% of the tile
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        top: constraints.maxHeight * 0.22,
                        child: AppImage(
                          imageUrl: configuredImageUrl,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                          memCacheWidth: 450,
                          memCacheHeight: 836,
                          filterQuality: FilterQuality.high,
                          errorWidget: const SizedBox.shrink(),
                        ),
                      ),
                      // Title
                      Positioned(
                        top: constraints.maxHeight * 0.055,
                        left: constraints.maxWidth * 0.07,
                        right: constraints.maxWidth * 0.07,
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          style: AppTextStyles.h2.copyWith(
                            color: Colors.white,
                            fontSize: 19.sp,
                            fontWeight: FontWeight.w900,
                            height: 1.02,
                            letterSpacing: -0.65,
                            shadows: const <Shadow>[
                              Shadow(
                                color: Color(0x18000000),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Badge
                      Positioned(
                        right: constraints.maxWidth * 0.09,
                        bottom: constraints.maxHeight * 0.07,
                        child: Transform.rotate(
                          angle: -0.04,
                          child: _DealBurstBadge(
                            size: burstSize,
                            text: resolvedHeroTileTheme.badgeText,
                            gradient: resolvedHeroTileTheme.badgeGradient,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    // ── No uploaded image: render the single catalog image, centred ──────
    // The API provides one product image for this tile. Show it once, centred
    // and large — no duplicated/rotated copies and no "+" overlay.
    final optimizedImage = ApiConstants.optimizedMedia(
      _firstRenderableImage(product),
      profile: CustomerImageProfile.seasonalHeroArtwork,
    );
    final String? singleImageUrl = optimizedImage.url?.trim().isNotEmpty == true
        ? optimizedImage.url
        : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => resolveMosaicTap(context, action, product.id),
        borderRadius: borderRadius,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Ink(
            decoration: tileBg,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final burstSize = constraints.maxWidth * 0.54;
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: <Widget>[
                    // Single image — centred, larger, fills the lower portion
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      top: constraints.maxHeight * 0.18,
                      child: singleImageUrl == null
                          ? const SizedBox.shrink()
                          : AppImage(
                              imageUrl: singleImageUrl,
                              fit: BoxFit.contain,
                              alignment: Alignment.bottomCenter,
                              memCacheWidth: optimizedImage.memCacheWidth,
                              memCacheHeight: optimizedImage.memCacheHeight,
                              filterQuality: FilterQuality.high,
                              errorWidget: const SizedBox.shrink(),
                            ),
                    ),
                    // Title
                    Positioned(
                      top: constraints.maxHeight * 0.055,
                      left: constraints.maxWidth * 0.07,
                      right: constraints.maxWidth * 0.07,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        style: AppTextStyles.h2.copyWith(
                          color: Colors.white,
                          fontSize: 19.sp,
                          fontWeight: FontWeight.w900,
                          height: 1.02,
                          letterSpacing: -0.65,
                          shadows: const <Shadow>[
                            Shadow(
                              color: Color(0x18000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Badge
                    Positioned(
                      right: constraints.maxWidth * 0.09,
                      bottom: constraints.maxHeight * 0.07,
                      child: Transform.rotate(
                        angle: -0.04,
                        child: _DealBurstBadge(
                          size: burstSize,
                          text: resolvedHeroTileTheme.badgeText,
                          gradient: resolvedHeroTileTheme.badgeGradient,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AssetMiniDealTile extends StatelessWidget {
  const _AssetMiniDealTile({
    required this.product,
    required this.assetPath,
    required this.title,
    required this.gradient,
    this.imageUrl,
    this.action,
  });

  final ProductEntity product;
  final String assetPath;
  final String? imageUrl;
  final String title;
  final List<Color> gradient;
  final MosaicTileAction? action;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(24.r);

    final image = imageUrl != null
        ? AppImage(
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            memCacheWidth: 450,
            memCacheHeight: 450,
            filterQuality: FilterQuality.high,
            errorWidget: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          )
        : Image.asset(
            assetPath,
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => resolveMosaicTap(context, action, product.id),
        borderRadius: borderRadius,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: gradient,
              ),
              borderRadius: borderRadius,
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                image,
                Positioned(
                  top: 12.h,
                  left: 12.w,
                  right: 18.w,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'NexaTrial',
                      color: Colors.white,
                      fontSize: 13.8.sp,
                      height: 0.95,
                      letterSpacing: -0.2,
                      fontWeight: FontWeight.w600,
                      shadows: const <Shadow>[
                        Shadow(
                          color: Color(0x22000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DealBurstBadge extends StatelessWidget {
  const _DealBurstBadge({
    required this.size,
    required this.text,
    this.gradient,
  });

  final double size;
  final String text;
  final List<Color>? gradient;

  @override
  Widget build(BuildContext context) {
    final defaultHeroTileTheme = HeroTileTheme.defaults();
    final badgeGradient = gradient ?? defaultHeroTileTheme.badgeGradient;
    return SizedBox(
      width: size,
      height: size,
      child: ClipPath(
        clipper: const _BurstClipper(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: badgeGradient,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 2,
            ),
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BurstClipper extends CustomClipper<Path> {
  const _BurstClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.86;
    const pointCount = 18;

    for (var index = 0; index < pointCount * 2; index++) {
      final isOuter = index.isEven;
      final radius = isOuter ? outerRadius : innerRadius;
      final angle = (math.pi / pointCount) * index - (math.pi / 2);
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _SeasonalTileSpec {
  const _SeasonalTileSpec({
    required this.product,
    required this.title,
    required this.gradient,
  });

  final ProductEntity product;
  final String title;
  final List<Color> gradient;
}

class _MiniAssetTileSpec {
  const _MiniAssetTileSpec({
    required this.product,
    required this.assetPath,
    required this.imageUrl,
    required this.title,
    required this.gradient,
    this.action,
  });

  final ProductEntity product;
  final String assetPath;
  final String? imageUrl;
  final String title;
  final List<Color> gradient;
  final MosaicTileAction? action;
}

/// Resolves a mosaic tile tap. When [action] is actionable it is honoured;
/// otherwise we fall back to opening the resolved product (legacy behaviour).
void resolveMosaicTap(
  BuildContext context,
  MosaicTileAction? action,
  String fallbackProductId,
) {
  if (action != null && action.isActionable) {
    switch (action.type) {
      case 'product':
        context.push('/product/${action.value}');
        return;
      case 'category':
        context.push('/categories/${action.value}/products');
        return;
      case 'tab':
        final route = _mosaicTabRoute(action.value!);
        if (route != null) {
          context.go(route);
          return;
        }
        break;
      case 'app_page':
        context.push(action.value!);
        return;
      case 'external_url':
        final uri = Uri.tryParse(action.value!);
        if (uri != null) {
          unawaited(
            launchUrl(uri, mode: LaunchMode.externalApplication),
          );
          return;
        }
        break;
      default:
        break;
    }
  }
  context.push('/product/$fallbackProductId');
}

String? _mosaicTabRoute(String key) {
  switch (key) {
    case 'home':
      return '/home';
    case 'off_zone':
      return '/off_zone';
    case 'super_mall':
      return '/super_mall';
    case 'cafe':
      return '/cafe';
  }
  return null;
}

List<ProductEntity> _buildHeroProducts(List<ProductEntity> products) {
  final renderable = products
      .where((product) => _firstRenderableImage(product) != null)
      .toList(growable: false);
  final source = renderable.isNotEmpty ? renderable : products;
  if (source.isEmpty) {
    return const <ProductEntity>[];
  }

  final exactRealMango = source.where((product) {
    final name = product.name.toLowerCase();
    return name.contains('real mango juice');
  }).toList(growable: false);
  if (exactRealMango.isNotEmpty) {
    return <ProductEntity>[exactRealMango.first];
  }

  final ranked = source.toList(growable: false)
    ..sort(
      (left, right) =>
          _heroProductScore(right).compareTo(_heroProductScore(left)),
    );
  final lead = ranked.first;

  return <ProductEntity>[lead];
}

List<_SeasonalTileSpec> _buildTiles(
  List<ProductEntity> products,
  SeasonalMosaicTheme? mosaicTheme,
) {
  final defaultMosaicTheme = SeasonalMosaicTheme.defaults();
  final heroTileTheme = mosaicTheme?.heroTile ?? defaultMosaicTheme.heroTile;
  final renderable = products
      .where((product) => _firstRenderableImage(product) != null)
      .toList(growable: false);
  final source = renderable.isNotEmpty ? renderable : products;
  if (source.isEmpty) {
    return const <_SeasonalTileSpec>[];
  }

  final selected = List<ProductEntity>.generate(
    5,
    (index) => source[index % source.length],
    growable: false,
  );

  return <_SeasonalTileSpec>[
    _SeasonalTileSpec(
      product: selected[0],
      title: heroTileTheme.title,
      gradient: heroTileTheme.gradient,
    ),
  ];
}

const List<List<List<String>>> _miniTileKeywordGroups = <List<List<String>>>[
  <List<String>>[
    <String>['coca-cola', 'cola', 'soft drink'],
    <String>['real mango juice', 'mango juice', 'juice'],
    <String>['amul vanilla magic', 'ice cream', 'vanilla magic'],
  ],
  <List<String>>[
    <String>['amul vanilla magic', 'ice cream', 'vanilla magic'],
    <String>['amul', 'frozen'],
  ],
  <List<String>>[
    <String>['lays classic', 'lays', 'chips', 'salted'],
    <String>['real mango juice', 'mango juice', 'juice'],
  ],
  <List<String>>[
    <String>['milky mist paneer', 'paneer'],
    <String>['amul taaza', 'taaza milk', 'milk'],
    <String>['egg', 'eggs'],
  ],
];

const List<String> _miniTileAssets = <String>[
  'assets/images/1ST_MINIBOX.png',
  'assets/images/2ND_MINIBOX.png',
  'assets/images/3RD_MINIBOX.png',
  'assets/images/4TH_MINIBOX.png',
];

List<_MiniAssetTileSpec> _buildMiniAssetTiles(
  List<ProductEntity> products,
  SeasonalMosaicTheme? mosaicTheme,
) {
  final defaultMosaicTheme = SeasonalMosaicTheme.defaults();
  final renderable = products
      .where((product) => _firstRenderableImage(product) != null)
      .toList(growable: false);
  final source = renderable.isNotEmpty ? renderable : products;
  if (source.isEmpty) {
    return const <_MiniAssetTileSpec>[];
  }

  // Honour the configured tile count (e.g. 6 for the 2x3 layout) instead of
  // hard-coding 4. Falls back to the default 4-tile set when no theme tiles
  // are supplied.
  final themedCount =
      mosaicTheme?.miniTiles.length ?? defaultMosaicTheme.miniTiles.length;
  final count = themedCount.clamp(1, 8);

  final usedIds = <String>{};

  return List<_MiniAssetTileSpec>.generate(count, (int index) {
    final themed = _miniTileThemeAt(mosaicTheme, defaultMosaicTheme, index);
    final fallbackTile = defaultMosaicTheme
        .miniTiles[index % defaultMosaicTheme.miniTiles.length];
    return _MiniAssetTileSpec(
      product: _pickMiniTileProduct(
        source,
        usedIds,
        _miniTileKeywordGroups[index % _miniTileKeywordGroups.length],
      ),
      assetPath: _miniTileAssets[index % _miniTileAssets.length],
      imageUrl: themed?.imageUrl,
      title: themed?.title ?? fallbackTile.title,
      gradient: themed?.gradient ?? fallbackTile.gradient,
      action: themed?.action,
    );
  });
}

MiniTileTheme? _miniTileThemeAt(
  SeasonalMosaicTheme? mosaicTheme,
  SeasonalMosaicTheme defaultMosaicTheme,
  int index,
) {
  final themedTiles = mosaicTheme?.miniTiles;
  if (themedTiles != null && themedTiles.length > index) {
    return themedTiles[index];
  }
  if (defaultMosaicTheme.miniTiles.length > index) {
    return defaultMosaicTheme.miniTiles[index];
  }
  return null;
}

ProductEntity _pickMiniTileProduct(
  List<ProductEntity> source,
  Set<String> usedIds,
  List<List<String>> keywordGroups,
) {
  for (final group in keywordGroups) {
    for (final product in source) {
      if (usedIds.contains(product.id)) {
        continue;
      }
      if (_matchesKeywordGroup(product, group)) {
        usedIds.add(product.id);
        return product;
      }
    }
  }

  for (final group in keywordGroups) {
    for (final product in source) {
      if (_matchesKeywordGroup(product, group)) {
        return product;
      }
    }
  }

  for (final product in source) {
    if (!usedIds.contains(product.id)) {
      usedIds.add(product.id);
      return product;
    }
  }

  return source.first;
}

bool _matchesKeywordGroup(ProductEntity product, List<String> keywords) {
  final haystack = <String?>[
    product.name,
    product.categoryName,
    product.description,
    if (product.tags.isNotEmpty) product.tags.join(' '),
  ].whereType<String>().join(' ').toLowerCase();

  return keywords.any(haystack.contains);
}

int _heroProductScore(ProductEntity product) {
  final haystack = <String?>[
    product.name,
    product.categoryName,
    if (product.tags.isNotEmpty) product.tags.join(' '),
  ].whereType<String>().join(' ').toLowerCase();

  const primaryKeywords = <String, int>{
    'nescafe': 18,
    'coffee': 14,
    'latte': 12,
    'chocolate': 11,
    'amul': 10,
    'milk': 8,
    'tea': 7,
    'butter': 6,
  };
  const secondaryKeywords = <String, int>{
    'biscuit': 4,
    'ice': 4,
    'snack': 3,
    'juice': 3,
    'mango': 3,
  };
  const avoidKeywords = <String>[
    'baby',
    'pampers',
    'diaper',
    'cerelac',
    'stage',
    'care',
    'beverage',
    'cola',
    'water',
    'tonic',
    'apple',
    'banana',
    'potato',
    'tomato',
    'spinach',
    'onion',
    'vegetable',
    'atta',
    'dal',
    'rice',
  ];

  var score = 0;
  primaryKeywords.forEach((keyword, weight) {
    if (haystack.contains(keyword)) {
      score += weight;
    }
  });
  secondaryKeywords.forEach((keyword, weight) {
    if (haystack.contains(keyword)) {
      score += weight;
    }
  });
  for (final keyword in avoidKeywords) {
    if (haystack.contains(keyword)) {
      score -= 6;
    }
  }

  if (product.isFeatured) {
    score += 2;
  }
  if (product.isOnSale) {
    score += 3;
  }
  if (product.thumbnailUrl != null && product.thumbnailUrl!.isNotEmpty) {
    score += 2;
  }

  return score;
}

String? _firstRenderableImage(ProductEntity product) {
  final candidates = <String?>[
    product.thumbnailUrl,
    ...product.images,
  ];

  for (final candidate in candidates) {
    final value = ApiConstants.resolveMediaUrl(candidate)?.trim();
    if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
      return value;
    }
  }

  return null;
}
