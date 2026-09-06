import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/presentation/providers/purchase_limits_provider.dart';
import 'package:bakaloo_flutter_app/features/wishlist/presentation/providers/wishlist_provider.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';

/// Layout of the card — grid (vertical lists) vs scroll (horizontal rails).
enum ProductCardStyle { grid, scroll }

/// Visual design variant of the product card, admin-configurable per section
/// (and globally) from the dashboard theme builder.
///
///   * [quickCommerceCompact] — the premium quick-commerce reference design
///     (price sticker, dashed discount line, rating/delivery rows). DEFAULT.
///   * [bakalooLegacyClean]  — the older, simpler/flatter card (plain price
///     text, minimal chrome). Kept so admins can opt back into the classic
///     look without a new widget.
enum ProductCardVariant { quickCommerceCompact, bakalooLegacyClean }

/// Resolve a [ProductCardVariant] from a backend config string.
///
/// Accepts the canonical UPPER_SNAKE tokens persisted by the dashboard
/// (`QUICK_COMMERCE_COMPACT`, `BAKALOO_LEGACY_CLEAN`). Any unknown / null /
/// empty value falls back to [ProductCardVariant.quickCommerceCompact] so old
/// themes and forward-incompatible values render the default safely.
ProductCardVariant productCardVariantFromString(String? raw) {
  switch ((raw ?? '').trim().toUpperCase()) {
    case 'BAKALOO_LEGACY_CLEAN':
      return ProductCardVariant.bakalooLegacyClean;
    case 'QUICK_COMMERCE_COMPACT':
      return ProductCardVariant.quickCommerceCompact;
    default:
      return ProductCardVariant.quickCommerceCompact;
  }
}

class ProductCard extends StatefulWidget {
  const ProductCard({
    required this.product,
    this.width = AppDimensions.productCardWidth,
    this.style,
    this.variant = ProductCardVariant.quickCommerceCompact,
    this.showWishlist = false,
    this.useCompactAddButton = false,
    this.showImageBorder = false,
    this.accentColor,
    this.onTap,
    this.onAdd,
    this.onOptionsTap,
    super.key,
  });

  final ProductEntity product;
  final double width;
  final ProductCardStyle? style;

  /// Visual design variant. Defaults to the premium quick-commerce card.
  final ProductCardVariant variant;
  final bool showWishlist;

  /// When true, grid cards render a compact square "+" button instead of the
  /// labelled "ADD" button. Used by the categories screen.
  final bool useCompactAddButton;

  /// When true, the product image sits inside a subtle bordered frame.
  final bool showImageBorder;

  /// Accent colour for the add/quantity control. Defaults to primary green.
  final Color? accentColor;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final VoidCallback? onOptionsTap;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? _inferStyle(context);
    final isGridStyle = style == ProductCardStyle.grid;

    final Widget card =
        isGridStyle ? _buildGridCard(context) : _buildScrollCard(context);

    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: SizedBox(width: widget.width.w, child: card),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Grid card (reference layout)
  //
  //   ┌───────────────────────────┐  ← white rounded box
  //   │  image  (♡, veg)          │
  //   │ ───────────────────────── │  ← faint divider
  //   │  95 g            [ ADD ]  │
  //   │                  3 options│
  //   └───────────────────────────┘
  //      ₹20   ₹25                   ← price (OUTSIDE the box)
  //      5% OFF on MRP
  //      Maggi Double Masala …
  //      ★ 4.4  (104)
  //      ◐ 28 mins
  //
  // The image + unit + ADD live inside ONE white box; price/name/rating/
  // delivery sit on the page background below it.
  // ───────────────────────────────────────────────────────────────────────
  Widget _buildGridCard(BuildContext context) {
    final product = widget.product;
    final cardWidth = widget.width.w;
    final tightGrid = widget.width < 112;
    final compactGrid = widget.width < 126;
    final imageHeight = cardWidth * 0.84;
    final unitFontSize = tightGrid ? 9.sp : 10.sp;
    final priceFontSize = tightGrid ? 14.sp : 16.sp;
    final comparePriceFontSize = tightGrid ? 10.sp : 11.5.sp;
    final titleFontSize = tightGrid ? 11.6.sp : 12.8.sp;
    final offFontSize = tightGrid ? 10.sp : 11.sp;
    final imageUrl = product.thumbnailUrl ??
        (product.images.isNotEmpty ? product.images.first : null);
    final optimizedImage = ApiConstants.optimizedMedia(
      imageUrl,
      profile: CustomerImageProfile.listProduct,
    );

    final effectivePrice = product.salePrice ?? product.price;
    final isOnSale =
        product.salePrice != null && product.salePrice! < product.price;
    final offAmount =
        isOnSale ? (product.price - product.salePrice!).toInt() : null;

    // ── The white box (image + divider + unit/ADD row) ────────────────────
    final whiteBox = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: const Color(0xFFEDEDED), width: 0.8),
      ),
      child: Stack(
        children: <Widget>[
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppDimensions.radiusLg),
                ),
                child: _buildImageArea(
                  product: product,
                  imageUrl: imageUrl,
                  optimizedImage: optimizedImage,
                  imageHeight: imageHeight,
                  isGridStyle: true,
                  tightGrid: tightGrid,
                  unitFontSize: unitFontSize,
                  style: ProductCardStyle.grid,
                  compactGrid: compactGrid,
                  showImageBorder: widget.showImageBorder,
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
              // Unit label (left) + ADD button (right) — both inside the box.
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tightGrid ? 8.w : 10.w,
                  8.h,
                  tightGrid ? 7.w : 8.w,
                  8.h,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          product.displayUnit.trim().isNotEmpty
                              ? product.displayUnit
                              : product.unit,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: unitFontSize,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF5A5A5A),
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                    Gap(4.w),
                    _IsolatedCartButton(
                      style: ProductCardStyle.grid,
                      compact: compactGrid,
                      tight: tightGrid,
                      product: product,
                      onAdd: widget.onAdd,
                      onOptionsTap: widget.onOptionsTap,
                      forceCompactPlus: widget.useCompactAddButton,
                      accentColor: widget.accentColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!product.inStock)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.overlayDark,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMd),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Out of stock',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // ── Below-box content (no border, on page background) ─────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        whiteBox,
        Gap(8.h),
        // Price + struck MRP
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              '₹${effectivePrice.toInt()}',
              style: TextStyle(
                fontSize: priceFontSize,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1A1A),
                height: 1.1,
              ),
            ),
            if (isOnSale) ...<Widget>[
              Gap(6.w),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '₹${product.price.toInt()}',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: comparePriceFontSize,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF999999),
                        decoration: TextDecoration.lineThrough,
                        decorationColor: const Color(0xFF999999),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        // Discount line — only when a real discount exists
        if (offAmount != null && offAmount > 0) ...<Widget>[
          Gap(3.h),
          Text(
            product.discountPercent > 0
                ? '${product.discountPercent}% OFF on MRP'
                : '₹$offAmount OFF',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: offFontSize,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2B7FFF),
            ),
          ),
        ],
        Gap(4.h),
        // Product name
        Text(
          product.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelLarge.copyWith(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: const Color(0xFF222222),
          ),
        ),
        // Rating row
        if (product.hasRating) ...<Widget>[
          Gap(4.h),
          Row(
            children: <Widget>[
              Icon(
                Icons.star_rounded,
                size: 12.sp,
                color: const Color(0xFFFFA000),
              ),
              Gap(2.w),
              Expanded(
                child: Text(
                  product.formattedRating,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF666666),
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ],
        // Delivery time row
        if (product.hasDeliveryTime) ...<Widget>[
          Gap(3.h),
          Row(
            children: <Widget>[
              PhosphorIcon(
                PhosphorIcons.clock,
                size: 11.sp,
                color: const Color(0xFF888888),
              ),
              Gap(3.w),
              Text(
                product.formattedDeliveryTime,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF888888),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
        Gap(4.h),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Scroll / rail card — compact single-box layout (unit + ADD overlaid on
  // the image) so the fixed horizontal rail height is preserved.
  // ───────────────────────────────────────────────────────────────────────
  Widget _buildScrollCard(BuildContext context) {
    final product = widget.product;
    final cardWidth = widget.width.w;
    final imageHeight = cardWidth * 0.88;
    final contentPadding = 10.w;
    final priceFontSize = 14.sp;
    final comparePriceFontSize = 12.sp;
    final titleFontSize = 12.8.sp;
    final unitFontSize = 10.8.sp;
    final offFontSize = 11.sp;
    final imageUrl = product.thumbnailUrl ??
        (product.images.isNotEmpty ? product.images.first : null);
    final optimizedImage = ApiConstants.optimizedMedia(
      imageUrl,
      profile: CustomerImageProfile.listProduct,
    );

    final effectivePrice = product.salePrice ?? product.price;
    final isOnSale =
        product.salePrice != null && product.salePrice! < product.price;
    final offAmount =
        isOnSale ? (product.price - product.salePrice!).toInt() : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Stack(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildImageArea(
                  product: product,
                  imageUrl: imageUrl,
                  optimizedImage: optimizedImage,
                  imageHeight: imageHeight,
                  isGridStyle: false,
                  tightGrid: false,
                  unitFontSize: unitFontSize,
                  style: ProductCardStyle.scroll,
                  compactGrid: false,
                  showImageBorder: false,
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(contentPadding, 6.h, contentPadding, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '₹${effectivePrice.toInt()}',
                        style: TextStyle(
                          fontSize: priceFontSize + 2,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1A1A),
                          height: 1.1,
                        ),
                      ),
                      if (isOnSale) ...<Widget>[
                        Gap(6.w),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '₹${product.price.toInt()}',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: comparePriceFontSize,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF999999),
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: const Color(0xFF999999),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (offAmount != null && offAmount > 0)
                  Padding(
                    padding: EdgeInsets.fromLTRB(contentPadding, 3.h, contentPadding, 0),
                    child: Text(
                      product.discountPercent > 0
                          ? '${product.discountPercent}% OFF on MRP'
                          : '₹$offAmount OFF',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: offFontSize,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2B7FFF),
                      ),
                    ),
                  ),
                Gap(4.h),
                Flexible(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: contentPadding),
                    child: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelLarge.copyWith(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: const Color(0xFF222222),
                      ),
                    ),
                  ),
                ),
                if (product.hasRating)
                  Padding(
                    padding: EdgeInsets.fromLTRB(contentPadding, 3.h, contentPadding, 0),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.star_rounded, size: 12.sp, color: const Color(0xFFFFA000)),
                        Gap(2.w),
                        Expanded(
                          child: Text(
                            product.formattedRating,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF666666),
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (product.hasDeliveryTime)
                  Padding(
                    padding: EdgeInsets.fromLTRB(contentPadding, 2.h, contentPadding, 0),
                    child: Row(
                      children: <Widget>[
                        PhosphorIcon(PhosphorIcons.clock, size: 11.sp, color: const Color(0xFF888888)),
                        Gap(3.w),
                        Text(
                          product.formattedDeliveryTime,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF888888),
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                Gap(6.h),
              ],
            ),
            if (!product.inStock)
              Positioned.fill(
                child: Container(
                  color: AppColors.overlayDark,
                  alignment: Alignment.center,
                  child: Text(
                    'Out of stock',
                    style: AppTextStyles.h3.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds the top image area. When [style] is a horizontal rail the unit
  /// chip + ADD button are overlaid on the image (compact); grid cards render
  /// those below the image instead (reference layout).
  Widget _buildImageArea({
    required ProductEntity product,
    required String? imageUrl,
    required OptimizedMediaAsset optimizedImage,
    required double imageHeight,
    required bool isGridStyle,
    required bool tightGrid,
    required double unitFontSize,
    required ProductCardStyle style,
    required bool compactGrid,
    bool showImageBorder = false,
  }) {
    // PHASE 4E: Delegate to _ProductCardImageArea StatelessWidget.
    // Being a separate StatelessWidget means Flutter's element reconciliation
    // can keep the subtree alive when only the cart quantity changes (which
    // is isolated to _IsolatedCartButton). The image, badges, and food marker
    // are unaffected by cart state and will not be re-laid-out.
    return _ProductCardImageArea(
      product: product,
      imageUrl: imageUrl,
      optimizedImage: optimizedImage,
      imageHeight: imageHeight,
      isGridStyle: isGridStyle,
      tightGrid: tightGrid,
      unitFontSize: unitFontSize,
      style: style,
      compactGrid: compactGrid,
      showImageBorder: showImageBorder,
      showWishlist: widget.showWishlist,
      onAdd: widget.onAdd,
      onOptionsTap: widget.onOptionsTap,
    );
  }

  ProductCardStyle _inferStyle(BuildContext context) {
    final axisDirection = Scrollable.maybeOf(context)?.widget.axisDirection;
    if (axisDirection == AxisDirection.left ||
        axisDirection == AxisDirection.right) {
      return ProductCardStyle.scroll;
    }
    return ProductCardStyle.grid;
  }
}

// ── PHASE 4E: Product card image area extracted as StatelessWidget ──────────
//
// Previously _buildImageArea was an inline method on _ProductCardState.
// Any rebuild of _ProductCardState (e.g. press animation via _isPressed) would
// re-execute the entire image-area build. As a StatelessWidget with a stable
// set of inputs (all derived from ProductEntity + widget config), Flutter's
// element tree can skip rebuilding it when only the state fields change.
//
// The cart and wishlist interactions stay isolated in _IsolatedCartButton and
// _IsolatedWishlistButton respectively — those are the only sub-widgets that
// rebuild on user actions.
class _ProductCardImageArea extends StatelessWidget {
  const _ProductCardImageArea({
    required this.product,
    required this.imageUrl,
    required this.optimizedImage,
    required this.imageHeight,
    required this.isGridStyle,
    required this.tightGrid,
    required this.unitFontSize,
    required this.style,
    required this.compactGrid,
    required this.showWishlist,
    this.showImageBorder = false,
    this.onAdd,
    this.onOptionsTap,
  });

  final ProductEntity product;
  final String? imageUrl;
  final OptimizedMediaAsset optimizedImage;
  final double imageHeight;
  final bool isGridStyle;
  final bool tightGrid;
  final double unitFontSize;
  final ProductCardStyle style;
  final bool compactGrid;
  final bool showWishlist;
  final bool showImageBorder;
  final VoidCallback? onAdd;
  final VoidCallback? onOptionsTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: imageHeight,
      width: double.infinity,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ClipRRect(
              borderRadius: showImageBorder
                  ? BorderRadius.circular(AppDimensions.radiusLg)
                  : const BorderRadius.vertical(
                      top: Radius.circular(AppDimensions.radiusLg),
                    ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: showImageBorder
                      ? Border.all(
                          color: const Color(0xFFDCDCE0),
                          width: 1,
                        )
                      : null,
                ),
                child: imageUrl == null || imageUrl!.isEmpty
                    ? const Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: AppColors.textDisabled,
                          size: 28,
                        ),
                      )
                    : SizedBox.expand(
                        child: AppImage(
                          imageUrl: optimizedImage.url ?? imageUrl!,
                          memCacheWidth: optimizedImage.memCacheWidth,
                          memCacheHeight: optimizedImage.memCacheHeight,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          placeholder: const ColoredBox(
                            color: Colors.white,
                            child: SizedBox.expand(),
                          ),
                          errorWidget: const ColoredBox(
                            color: Colors.white,
                            child: Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: AppColors.textDisabled,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          if (showWishlist)
            Positioned(
              top: 8.h,
              right: 8.w,
              child: _IsolatedWishlistButton(
                product: product,
                showWishlist: showWishlist,
              ),
            ),
          // Origin badge (top-left)
          if (product.hasOriginTag && product.isImported)
            Positioned(
              top: 6.h,
              left: 6.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(4.r),
                  border: Border.all(
                    color: const Color(0xFFFFB74D),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  'Imported',
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE65100),
                    height: 1.1,
                  ),
                ),
              ),
            ),
          // Food marker (veg / non-veg / egg) — shape + colour, image edge
          if (product.hasFoodMarker)
            Positioned(
              right: 8.w,
              bottom: 8.h,
              child: _FoodMarkerBox(product: product),
            ),
          // Rails keep the compact overlay (unit chip + ADD) so the fixed
          // rail height is preserved.
          if (!isGridStyle) ...<Widget>[
            Positioned(
              right: tightGrid ? 6.w : 8.w,
              bottom: tightGrid ? 6.h : 8.h,
              child: _IsolatedCartButton(
                style: style,
                compact: compactGrid,
                tight: tightGrid,
                product: product,
                onAdd: onAdd,
                onOptionsTap: onOptionsTap,
              ),
            ),
            if (product.displayUnit.trim().isNotEmpty)
              Positioned(
                left: tightGrid ? 6.w : 8.w,
                bottom: tightGrid ? 6.h : 8.h,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: tightGrid ? 6.w : 8.w,
                    vertical: tightGrid ? 2.h : 3.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6.r),
                    // PHASE 3D: Replace blurred shadow with a simple border.
                    border: Border.all(
                      color: const Color(0xFFE0E0E0),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    product.displayUnit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: unitFontSize,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3A3A3A),
                      height: 1.1,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Veg / non-veg / egg marker — square outline + filled dot (shape + colour
/// so it is distinguishable without relying on colour alone).
class _FoodMarkerBox extends StatelessWidget {
  const _FoodMarkerBox({required this.product});

  final ProductEntity product;

  @override
  Widget build(BuildContext context) {
    final color = product.isVeg
        ? const Color(0xFF2E7D32)
        : product.isNonVeg
            ? const Color(0xFFC62828)
            : const Color(0xFFF9A825);

    final isEgg = product.isEgg;

    return Container(
      width: 16.w,
      height: 16.w,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3.r),
        border: Border.all(color: color, width: 1.5),
      ),
      alignment: Alignment.center,
      child: isEgg
          // Egg: hollow ring to distinguish from veg/non-veg solid dots.
          ? Container(
              width: 8.w,
              height: 8.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.6),
              ),
            )
          : Container(
              width: 8.w,
              height: 8.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
    );
  }
}

/// Isolated Consumer wrapper: only this widget rebuilds on wishlist changes.
class _IsolatedWishlistButton extends ConsumerWidget {
  const _IsolatedWishlistButton({
    required this.product,
    required this.showWishlist,
  });

  final ProductEntity product;
  final bool showWishlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!showWishlist) return const SizedBox.shrink();

    final isWishlisted = ref.watch(
      wishlistProvider.select(
        (wishlistAsync) => switch (wishlistAsync) {
          AsyncData(:final value) => value.items.any(
              (item) => item.productId == product.id,
            ),
          _ => false,
        },
      ),
    );
    final authGate = ref.read(authGateControllerProvider);

    return _WishlistButton(
      product: product,
      isWishlisted: isWishlisted,
      authGate: authGate,
    );
  }
}

class _WishlistButton extends ConsumerWidget {
  const _WishlistButton({
    required this.product,
    required this.isWishlisted,
    required this.authGate,
  });

  final ProductEntity product;
  final bool isWishlisted;
  final AuthGateController authGate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () async {
          final allowed = await authGate.protectWishlist(context, product);
          if (!allowed || !context.mounted) return;
          final result =
              await ref.read(wishlistProvider.notifier).toggleWishlist(product);
          if (!context.mounted || result.isSuccess) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.failure!.message),
            ),
          );
        },
        customBorder: const CircleBorder(),
        child: Padding(
          padding: EdgeInsets.all(6.w),
          child: PhosphorIcon(
            isWishlisted ? PhosphorIcons.heartFill : PhosphorIcons.heart,
            size: 18,
            color: isWishlisted ? AppColors.errorRed : const Color(0xFF606060),
          ),
        ),
      ),
    );
  }
}

/// Isolated Consumer wrapper: only this widget rebuilds on cart changes.
class _IsolatedCartButton extends ConsumerWidget {
  const _IsolatedCartButton({
    required this.style,
    required this.compact,
    required this.tight,
    required this.product,
    this.onAdd,
    this.onOptionsTap,
    this.forceCompactPlus = false,
    this.accentColor,
  });

  final ProductCardStyle style;
  final bool compact;
  final bool tight;
  final ProductEntity product;
  final VoidCallback? onAdd;
  final VoidCallback? onOptionsTap;
  final bool forceCompactPlus;
  final Color? accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Multi-option families never reflect a combined quantity on the card —
    // they always show ADD + "N options"; exact quantities live in the sheet.
    final quantity = product.hasMultipleOptions
        ? 0
        : ref.watch(cartItemQuantityProvider(product.id));
    final authGate = ref.read(authGateControllerProvider);

    return _ZeptoAddQtyButton(
      style: style,
      compact: compact,
      tight: tight,
      quantity: quantity,
      product: product,
      authGate: authGate,
      onAdd: onAdd,
      onOptionsTap: onOptionsTap,
      forceCompactPlus: forceCompactPlus,
      accentColor: accentColor,
    );
  }
}

class _ZeptoAddQtyButton extends ConsumerWidget {
  const _ZeptoAddQtyButton({
    required this.style,
    required this.compact,
    required this.tight,
    required this.quantity,
    required this.product,
    required this.authGate,
    this.onAdd,
    this.onOptionsTap,
    this.forceCompactPlus = false,
    this.accentColor,
  });

  final ProductCardStyle style;
  final bool compact;
  final bool tight;
  final int quantity;
  final ProductEntity product;
  final AuthGateController authGate;
  final VoidCallback? onAdd;
  final VoidCallback? onOptionsTap;
  final bool forceCompactPlus;
  final Color? accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Purchase-limits: null == unrestricted (the common case, zero extra
    // visual/logic changes). Watched (not read) so this button live-updates
    // — e.g. right after this exact tap pushes the product to its limit.
    final purchaseLimitStatus =
        ref.watch(purchaseLimitStatusProvider(product.id));
    final isAtLimit = purchaseLimitStatus?.isAtLimit ?? false;
    final greenBorder = accentColor ?? AppColors.primaryGreen;
    final buttonHeight = tight ? 30.h : 32.h;
    // Inline grid ADD buttons sit next to the unit label in a narrow 3-col
    // cell, so they are kept compact to leave room for "200 g" / "6 eggs".
    final gridButtonWidth = tight
        ? 42.w
        : compact
            ? 48.w
            : 56.w;
    final controlWidth = tight ? 17.w : 19.w;
    final quantityWidth = tight ? 12.w : 14.w;
    final iconSize = tight ? 11.0 : 12.0;
    final addFontSize = tight
        ? 10.sp
        : compact
            ? 10.5.sp
            : 11.5.sp;

    if (quantity > 0) {
      return Container(
        height: buttonHeight,
        decoration: BoxDecoration(
          color: greenBorder,
          borderRadius: BorderRadius.circular(8.r),
          // PHASE 3D: Reduced blur 6→2 on active cart button.
          // The green background already makes it visually prominent;
          // a tight offset shadow is sufficient.
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            InkWell(
              onTap: () async {
                if (quantity == 1) {
                  final result = await ref
                      .read(cartProvider.notifier)
                      .removeItem(product.id);
                  if (!context.mounted || result.isSuccess) return;
                  showCartSnackBar(context, result.failure!.message);
                  return;
                }
                final result = await ref
                    .read(cartProvider.notifier)
                    .updateItem(product.id, quantity - 1);
                if (!context.mounted || result.isSuccess) return;
                showCartSnackBar(context, result.failure!.message);
              },
              child: SizedBox(
                width: controlWidth,
                child: Center(
                  child: PhosphorIcon(
                    PhosphorIcons.minus,
                    size: iconSize,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: quantityWidth,
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: tight ? 12.sp : 14.sp,
                ),
              ),
            ),
            InkWell(
              onTap: () async {
                if (quantity >= 50) return;
                // Re-checked fresh on every tap (ref.read, not the watched
                // value above) so a stale cache can never let a mutation
                // through — block before it ever reaches the network.
                final status =
                    ref.read(purchaseLimitStatusProvider(product.id));
                if (status?.isAtLimit ?? false) {
                  AppToast.show(context, 'Maximum product order complete');
                  return;
                }
                final result = await ref
                    .read(cartProvider.notifier)
                    .updateItem(product.id, quantity + 1);
                if (!context.mounted || result.isSuccess) return;
                showCartSnackBar(context, result.failure!.message);
              },
              splashColor: isAtLimit ? Colors.transparent : null,
              highlightColor: isAtLimit ? Colors.transparent : null,
              child: SizedBox(
                width: controlWidth,
                child: Center(
                  child: Opacity(
                    opacity: isAtLimit ? 0.4 : 1,
                    child: PhosphorIcon(
                      PhosphorIcons.plus,
                      size: iconSize,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final bool isGrid = style == ProductCardStyle.grid;
    final bool showOptions = product.hasMultipleOptions;
    // Categories screen uses a compact square "+" button (no "ADD" label).
    final bool compactPlus = forceCompactPlus && isGrid && !showOptions;
    // A multi-option family's ADD button opens a sheet of sibling options
    // rather than adding this exact representative product — this card's
    // own isAtLimit status shouldn't grey out (or block) that sheet, since
    // other options inside it may not be restricted at all.
    final bool disableDirectAdd = isAtLimit && !showOptions;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        // PHASE 3D: Reduced blur 5→2 on ADD button. The Material InkWell
        // provides sufficient visual feedback; a deep shadow is unnecessary.
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        child: InkWell(
          onTap: product.inStock
              ? () async {
                  // Multi-option products open the option sheet instead of
                  // adding the representative directly.
                  if (product.hasMultipleOptions && onOptionsTap != null) {
                    onOptionsTap!.call();
                    return;
                  }
                  // Re-checked fresh on every tap (ref.read, not the
                  // watched value above) so a stale cache can never let a
                  // mutation through — block before it ever reaches the
                  // network.
                  final status =
                      ref.read(purchaseLimitStatusProvider(product.id));
                  if (status?.isAtLimit ?? false) {
                    AppToast.show(context, 'Maximum product order complete');
                    return;
                  }
                  final allowed = await authGate.protectAddToCart(
                    context,
                    product,
                  );
                  if (!allowed || !context.mounted) return;
                  final result = await ref
                      .read(cartProvider.notifier)
                      .addItem(product.id, 1, product: product);
                  if (!context.mounted) return;
                  if (!result.isSuccess) {
                    showCartSnackBar(context, result.failure!.message);
                    return;
                  }
                  onAdd?.call();
                }
              : null,
          borderRadius: BorderRadius.circular(8.r),
          splashColor: disableDirectAdd ? Colors.transparent : null,
          highlightColor: disableDirectAdd ? Colors.transparent : null,
          child: Opacity(
            opacity: disableDirectAdd ? 0.4 : 1,
            child: Container(
            // Multi-option grid buttons grow taller to stack "ADD" over the
            // "N options" line INSIDE the green border (reference layout).
            height: isGrid && showOptions ? buttonHeight + 16.h : buttonHeight,
            width: compactPlus
                ? buttonHeight
                : isGrid
                    ? gridButtonWidth
                    : buttonHeight,
            padding: EdgeInsets.symmetric(vertical: 3.h),
            decoration: BoxDecoration(
              border: Border.all(color: greenBorder, width: 1.5),
              borderRadius: BorderRadius.circular(8.r),
            ),
            alignment: Alignment.center,
            child: compactPlus
                ? PhosphorIcon(
                    PhosphorIcons.plusBold,
                    size: tight ? 15.0 : 18.0,
                    color: greenBorder,
                  )
                : isGrid
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'ADD',
                            style: TextStyle(
                              color: greenBorder,
                              fontWeight: FontWeight.w700,
                              fontSize: addFontSize,
                              letterSpacing: 0.4,
                              height: 1.0,
                            ),
                          ),
                          if (showOptions)
                            Text(
                              '${product.optionCount} options',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 8.5.sp,
                                fontWeight: FontWeight.w500,
                                color: greenBorder,
                                height: 1.2,
                              ),
                            ),
                        ],
                      )
                    : PhosphorIcon(
                        PhosphorIcons.plusBold,
                        size: tight ? 15.0 : 18.0,
                        color: greenBorder,
                      ),
          ),
          ),
        ),
      ),
    );
  }
}
