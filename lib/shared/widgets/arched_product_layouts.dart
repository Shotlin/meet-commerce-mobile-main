import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/shared/widgets/arched_product_card.dart';

/// Shared parameters for all arched product layout variants.
class ArchedLayoutParams {
  const ArchedLayoutParams({
    required this.products,
    required this.backgroundColor,
    required this.cardShape,
    required this.archHeight,
    required this.cornerRadius,
    this.boxGradientColors,
    this.cardWidth = 156,
  });

  final List<ProductEntity> products;
  final Color backgroundColor;
  final String cardShape;
  final double archHeight;
  final double cornerRadius;
  final List<Color>? boxGradientColors;
  final double cardWidth;
}

/// Builds the appropriate layout widget for the given variant key.
Widget buildArchedProductLayout(String variant, ArchedLayoutParams params) {
  switch (variant) {
    case 'grid_2col':
      return _ArchedGrid2Col(params: params);
    case 'grid_3col':
      return _ArchedGrid3Col(params: params);
    case 'hero_plus_grid':
      return _ArchedHeroPlusGrid(params: params);
    case 'stacked_cards':
      return _ArchedStackedCards(params: params);
    default:
      return _ArchedHorizontalScroll(params: params);
  }
}

// ─────────────────────────────────────────────────────────
// Layout 1: Horizontal Scroll (DEFAULT — current behavior)
// ─────────────────────────────────────────────────────────

class _ArchedHorizontalScroll extends StatelessWidget {
  const _ArchedHorizontalScroll({required this.params});

  final ArchedLayoutParams params;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 272.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: params.products.length,
        separatorBuilder: (_, __) => Gap(12.w),
        itemBuilder: (BuildContext context, int index) {
          final product = params.products[index];
          // PHASE 3E: RepaintBoundary isolates each arched card's raster
          // layer. When the cart changes, only the card whose quantity
          // changed repaints; the others stay in the GPU texture cache.
          return RepaintBoundary(
            child: ArchedProductCard(
              product: product,
              backgroundColor: params.backgroundColor,
              cardShape: params.cardShape,
              archHeight: params.archHeight,
              cornerRadius: params.cornerRadius,
              boxGradientColors: params.boxGradientColors,
              width: params.cardWidth,
              onTap: () => context.push('/product/${product.id}'),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────
// Layout 2: Grid 2-Column
// ─────────────────────────────────────

class _ArchedGrid2Col extends StatelessWidget {
  const _ArchedGrid2Col({required this.params});

  final ArchedLayoutParams params;

  @override
  Widget build(BuildContext context) {
    final spacing = 12.w;
    final runSpacing = 12.h;

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: <Widget>[
            for (final product in params.products)
              SizedBox(
                width: itemWidth,
                child: RepaintBoundary(
                  child: ArchedProductCard(
                    product: product,
                    backgroundColor: params.backgroundColor,
                    cardShape: params.cardShape,
                    archHeight: params.archHeight,
                    cornerRadius: params.cornerRadius,
                    boxGradientColors: params.boxGradientColors,
                    onTap: () => context.push('/product/${product.id}'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────
// Layout 3: Grid 3-Column (compact)
// ─────────────────────────────────────

class _ArchedGrid3Col extends StatelessWidget {
  const _ArchedGrid3Col({required this.params});

  final ArchedLayoutParams params;

  @override
  Widget build(BuildContext context) {
    final spacing = 8.w;
    final runSpacing = 8.h;

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - spacing * 2) / 3;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: <Widget>[
            for (final product in params.products)
              SizedBox(
                width: itemWidth,
                child: RepaintBoundary(
                  child: ArchedProductCard(
                    product: product,
                    backgroundColor: params.backgroundColor,
                    cardShape: params.cardShape,
                    archHeight: params.archHeight,
                    cornerRadius: params.cornerRadius,
                    boxGradientColors: params.boxGradientColors,
                    onTap: () => context.push('/product/${product.id}'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ──────────────────────────────────────────────
// Layout 4: Hero + Grid (1 large + 2 small)
// ──────────────────────────────────────────────

class _ArchedHeroPlusGrid extends StatelessWidget {
  const _ArchedHeroPlusGrid({required this.params});

  final ArchedLayoutParams params;

  @override
  Widget build(BuildContext context) {
    if (params.products.isEmpty) return const SizedBox.shrink();

    final hero = params.products.first;
    final rest = params.products.skip(1).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          flex: 5,
          child: ArchedProductCard(
            product: hero,
            backgroundColor: params.backgroundColor,
            cardShape: params.cardShape,
            archHeight: params.archHeight,
            cornerRadius: params.cornerRadius,
            boxGradientColors: params.boxGradientColors,
            onTap: () => context.push('/product/${hero.id}'),
          ),
        ),
        Gap(10.w),
        Expanded(
          flex: 4,
          child: Column(
            children: rest.take(3).map((ProductEntity product) {
              return Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: ArchedProductCard(
                  product: product,
                  backgroundColor: params.backgroundColor,
                  cardShape: params.cardShape,
                  archHeight: params.archHeight * 0.7,
                  cornerRadius: params.cornerRadius * 0.8,
                  boxGradientColors: params.boxGradientColors,
                  onTap: () => context.push('/product/${product.id}'),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────
// Layout 5: Stacked Cards (full-width, vertical)
// ──────────────────────────────────────────────────

class _ArchedStackedCards extends StatelessWidget {
  const _ArchedStackedCards({required this.params});

  final ArchedLayoutParams params;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: params.products.map((ProductEntity product) {
        return Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: SizedBox(
            width: double.infinity,
            // PHASE 3E: RepaintBoundary per stacked card.
            child: RepaintBoundary(
              child: ArchedProductCard(
                product: product,
                backgroundColor: params.backgroundColor,
                cardShape: params.cardShape,
                archHeight: params.archHeight,
                cornerRadius: params.cornerRadius,
                boxGradientColors: params.boxGradientColors,
                onTap: () => context.push('/product/${product.id}'),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
