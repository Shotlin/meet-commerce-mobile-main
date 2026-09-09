import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/products/data/models/product_options_response.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/product_options_provider.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/presentation/providers/purchase_limits_provider.dart';
import 'package:bakaloo_flutter_app/features/wishlist/presentation/providers/wishlist_provider.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';

// FreshCuts brand system for this card — kept local rather than pulled from
// AppColors since these are exact tokens from the premium search-grid
// design spec (a strong CTA red distinct from the softer brandRed used
// elsewhere, plus dedicated success/soft-surface tokens for badges/chips).
class _Palette {
  _Palette._();
  static const Color brandRed = Color(0xFFC32D2E);
  static const Color ctaRed = Color(0xFFD92332);
  static const Color textMain = Color(0xFF111318);
  static const Color textSecondary = Color(0xFF6F7785);
  static const Color textMuted = Color(0xFF9299A5);
  static const Color border = Color(0xFFEAECF0);
  static const Color wishlistBorder = Color(0xFFECEEF1);
  static const Color selectedChipBg = Color(0xFFFFF4F4);
  static const Color unselectedChipBg = Color(0xFFF5F6F8);
  static const Color unselectedChipText = Color(0xFF697281);
  static const Color discountGreen = Color(0xFF159447);
  static const Color discountGreenBg = Color(0xFFEAF8EF);
  static const Color premiumCutBg = Color(0xFFFFF0F1);
  static const Color deliveryText = Color(0xFF7A8391);
  static const Color outOfStockBg = Color(0xFFECEEF2);
  static const Color outOfStockText = Color(0xFF7D8591);
}

/// Merges one real sibling option (fetched from the product-family/options
/// API) into a base [ProductEntity] so the rest of the app's cart/wishlist/
/// navigation logic — which is written against [ProductEntity] — can treat
/// the selected variant exactly like any other product. Only the fields
/// that genuinely vary by weight/pack (price, stock, unit, id, imagery,
/// badges, delivery ETA) are overwritten; everything else (name, tags,
/// description, family metadata) is inherited from the base representative.
ProductEntity _mergeOption(ProductEntity base, ProductOptionItem option) {
  return base.copyWith(
    id: option.id,
    price: option.price,
    salePrice: option.salePrice,
    stockQuantity: option.stockQuantity ?? base.stockQuantity,
    isActive: option.isAvailable,
    unit: option.unit,
    optionLabel: option.optionLabel,
    netQuantity: option.netQuantity,
    thumbnailUrl: option.thumbnailUrl ?? base.thumbnailUrl,
    images: option.images.isNotEmpty ? option.images : base.images,
    foodType: option.foodType,
    originTag: option.originTag,
    customBadges: option.customBadges.isNotEmpty
        ? option.customBadges
        : base.customBadges,
    displayDeliveryMinutes:
        option.displayDeliveryMinutes ?? base.displayDeliveryMinutes,
    shopProductId: option.shopProductId ?? base.shopProductId,
    shopId: option.shopId ?? base.shopId,
  );
}

/// Short attribute line under the title (e.g. "Lean • High Protein",
/// "Tender • Juicy"). Sourced from real catalog tags — never invented —
/// falling back to the product description, and hidden entirely when
/// neither is present so no blank space is reserved for it.
String? _subtitleFor(ProductEntity product) {
  final tags = product.tags.where((t) => t.trim().isNotEmpty).take(2).toList();
  if (tags.isNotEmpty) return tags.join(' • ');
  final description = product.description?.trim();
  if (description != null && description.isNotEmpty) return description;
  return null;
}

/// Product card for the search-results grid — image with badge/wishlist
/// overlay, name, subtitle, inline weight/pack chips (real sibling data
/// from the product-family options API) and a price + delivery + add row.
///
/// Wired to the same cart/wishlist/purchase-limit/auth-gate providers as
/// the rest of the app, so Add/quantity/wishlist behave identically to
/// every other product surface. Selecting a different weight/pack chip
/// swaps the card in place to that real sibling product — its own id,
/// price, stock and delivery ETA — without leaving the grid.
class SearchProductGridCard extends ConsumerStatefulWidget {
  const SearchProductGridCard({required this.product, super.key});

  final ProductEntity product;

  @override
  ConsumerState<SearchProductGridCard> createState() =>
      _SearchProductGridCardState();
}

class _SearchProductGridCardState
    extends ConsumerState<SearchProductGridCard> {
  late String _selectedId = widget.product.id;

  @override
  void didUpdateWidget(covariant SearchProductGridCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) {
      _selectedId = widget.product.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    List<ProductOptionItem> options = const <ProductOptionItem>[];
    if (product.hasMultipleOptions) {
      final familyId = product.productFamilyId ?? product.id;
      final optionsAsync = ref.watch(productOptionsProvider(familyId));
      options = optionsAsync.asData?.value.options ?? const <ProductOptionItem>[];
    }

    ProductOptionItem? selectedOption;
    for (final option in options) {
      if (option.id == _selectedId) {
        selectedOption = option;
        break;
      }
    }

    final displayed =
        selectedOption != null ? _mergeOption(product, selectedOption) : product;
    final badge = displayed.customBadges.isNotEmpty
        ? displayed.customBadges.first
        : null;
    final subtitle = _subtitleFor(displayed);

    return InkWell(
      onTap: () => context.push('/product/${displayed.id}'),
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: _Palette.border),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ImageArea(product: displayed, badge: badge),
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 9.w, 10.w, 9.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    height: 37.w,
                    child: Text(
                      displayed.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15.5.sp,
                        fontWeight: FontWeight.w700,
                        color: _Palette.textMain,
                        height: 1.15,
                      ),
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    Gap(2.w),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w500,
                        color: _Palette.textSecondary,
                      ),
                    ),
                  ],
                  Gap(6.w),
                  _VariantChipsRow(
                    fallbackLabel: displayed.displayUnit,
                    options: options,
                    selectedId: _selectedId,
                    onSelect: (option) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedId = option.id);
                    },
                    onMore: () => showProductOptionsSheet(context, product),
                  ),
                  Gap(6.w),
                  _PriceRow(product: displayed),
                  Gap(6.w),
                  _DeliveryActionRow(product: displayed),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageArea extends ConsumerWidget {
  const _ImageArea({required this.product, required this.badge});

  final ProductEntity product;
  final String? badge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWishlisted = ref.watch(
      wishlistProvider.select(
        (wishlistAsync) => switch (wishlistAsync) {
          AsyncData(:final value) =>
            value.items.any((item) => item.productId == product.id),
          _ => false,
        },
      ),
    );

    final imageUrl = product.thumbnailUrl ??
        (product.images.isNotEmpty ? product.images.first : null);
    final optimizedImage = ApiConstants.optimizedMedia(
      imageUrl,
      profile: CustomerImageProfile.listProduct,
    );

    return AspectRatio(
      aspectRatio: 1.10,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Opacity(
            opacity: product.inStock ? 1 : 0.75,
            child: ColoredBox(
              color: const Color(0xFFF6F7F9),
              child: optimizedImage.url == null || optimizedImage.url!.isEmpty
                  ? Center(
                      child: PhosphorIcon(
                        PhosphorIcons.image,
                        color: _Palette.textSecondary,
                        size: 32.sp,
                      ),
                    )
                  : AppImage(
                      imageUrl: optimizedImage.url!,
                      memCacheWidth: optimizedImage.memCacheWidth,
                      memCacheHeight: optimizedImage.memCacheHeight,
                      fit: BoxFit.cover,
                      errorWidget: Center(
                        child: PhosphorIcon(
                          PhosphorIcons.imageBroken,
                          color: _Palette.textSecondary,
                          size: 32.sp,
                        ),
                      ),
                    ),
            ),
          ),
          if (badge != null)
            Positioned(
              top: 10.w,
              left: 10.w,
              child: _ProductBadge(label: badge!),
            ),
          Positioned(
            top: 9.w,
            right: 9.w,
            child: _WishlistHeartButton(
              product: product,
              isWishlisted: isWishlisted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductBadge extends StatelessWidget {
  const _ProductBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final lower = label.toLowerCase();
    final Color background;
    final Color foreground;
    if (lower.contains('fresh')) {
      background = _Palette.discountGreenBg;
      foreground = _Palette.discountGreen;
    } else if (lower.contains('premium')) {
      background = _Palette.premiumCutBg;
      foreground = _Palette.brandRed;
    } else {
      background = _Palette.ctaRed;
      foreground = Colors.white;
    }

    return Container(
      height: 27.w,
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13.r),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11.5.sp,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

class _WishlistHeartButton extends ConsumerWidget {
  const _WishlistHeartButton({
    required this.product,
    required this.isWishlisted,
  });

  final ProductEntity product;
  final bool isWishlisted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      label: 'Add ${product.name} to wishlist',
      button: true,
      child: Material(
        color: Colors.white.withValues(alpha: 0.98),
        shape:
            const CircleBorder(side: BorderSide(color: _Palette.wishlistBorder)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () async {
            HapticFeedback.selectionClick();
            final authGate = ref.read(authGateControllerProvider);
            final allowed = await authGate.protectWishlist(context, product);
            if (!allowed || !context.mounted) return;
            final result = await ref
                .read(wishlistProvider.notifier)
                .toggleWishlist(product);
            if (!context.mounted || result.isSuccess) return;
            AppToast.show(context, result.failure!.message);
          },
          child: SizedBox(
            width: 36.w,
            height: 36.w,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: PhosphorIcon(
                  isWishlisted ? PhosphorIcons.heartFill : PhosphorIcons.heart,
                  key: ValueKey<bool>(isWishlisted),
                  size: 20.sp,
                  color: _Palette.brandRed,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline weight/pack selector — mirrors the reference "[500 g] [1 kg]"
/// pills. Backed by the same product-family options endpoint the sheet
/// uses, so labels (500 g / 1 kg, or Pack of 6 / Pack of 12 for eggs) come
/// straight from the catalog. Shows up to 2 real siblings (always including
/// whichever one is currently selected) plus a "+N" pill that opens the
/// full options sheet for the rest. Falls back to a single static chip
/// while loading, on error, or for single-option products.
class _VariantChipsRow extends StatelessWidget {
  const _VariantChipsRow({
    required this.fallbackLabel,
    required this.options,
    required this.selectedId,
    required this.onSelect,
    required this.onMore,
  });

  final String fallbackLabel;
  final List<ProductOptionItem> options;
  final String selectedId;
  final ValueChanged<ProductOptionItem> onSelect;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    if (fallbackLabel.trim().isEmpty && options.length < 2) {
      return const SizedBox.shrink();
    }
    if (options.length < 2) {
      return SizedBox(
        height: 30.w,
        child: _Chip(label: fallbackLabel, selected: true),
      );
    }

    ProductOptionItem? selected;
    final others = <ProductOptionItem>[];
    for (final option in options) {
      if (option.id == selectedId && selected == null) {
        selected = option;
      } else {
        others.add(option);
      }
    }
    final shown = <ProductOptionItem>[
      if (selected != null) selected,
      ...others,
    ].take(2).toList();
    final extra = options.length - shown.length;

    return SizedBox(
      height: 30.w,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < shown.length; i++) ...<Widget>[
              if (i > 0) Gap(6.w),
              _Chip(
                label: shown[i].displayUnit,
                selected: shown[i].id == selectedId,
                onTap: shown[i].id == selectedId
                    ? null
                    : () => onSelect(shown[i]),
              ),
            ],
            if (extra > 0) ...<Widget>[
              Gap(6.w),
              _MoreChip(count: extra, onTap: onMore),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30.w,
        padding: EdgeInsets.symmetric(horizontal: 11.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _Palette.selectedChipBg : _Palette.unselectedChipBg,
          borderRadius: BorderRadius.circular(9.r),
          border: Border.all(
            color: selected ? _Palette.brandRed : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w600,
            color: selected ? _Palette.brandRed : _Palette.unselectedChipText,
          ),
        ),
      ),
    );
  }
}

class _MoreChip extends StatelessWidget {
  const _MoreChip({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30.w,
        padding: EdgeInsets.symmetric(horizontal: 11.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _Palette.unselectedChipBg,
          borderRadius: BorderRadius.circular(9.r),
        ),
        child: Text(
          '+$count',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w600,
            color: _Palette.unselectedChipText,
          ),
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.product});

  final ProductEntity product;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6.w,
      children: <Widget>[
        Text(
          product.effectivePrice.toInrCurrency,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18.5.sp,
            fontWeight: FontWeight.w800,
            color: _Palette.textMain,
          ),
        ),
        if (product.isOnSale) ...<Widget>[
          Text(
            product.price.toInrCurrency,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w500,
              color: _Palette.textMuted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          Text(
            '${product.discountPercent}% off',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w700,
              color: _Palette.discountGreen,
            ),
          ),
        ],
      ],
    );
  }
}

/// Bottom row: delivery ETA on the left (hidden entirely when the backend
/// doesn't supply one — never a hardcoded "30 mins"), compact add/quantity
/// control on the right.
class _DeliveryActionRow extends StatelessWidget {
  const _DeliveryActionRow({required this.product});

  final ProductEntity product;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (product.hasDeliveryTime)
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.bolt_rounded, size: 17.sp, color: _Palette.ctaRed),
                Gap(2.w),
                Flexible(
                  child: Text(
                    product.formattedDeliveryTime,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: _Palette.deliveryText,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          const SizedBox.shrink(),
        _AddToCartControl(product: product),
      ],
    );
  }
}

/// The "+" CTA that morphs into a [-] qty [+] stepper in the same footprint
/// once the item is in the cart — mirrors the rest of the app's cart
/// mutation flow (auth gate + purchase-limit re-check on every tap).
class _AddToCartControl extends ConsumerWidget {
  const _AddToCartControl({required this.product});

  final ProductEntity product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(cartItemQuantityProvider(product.id));
    final purchaseLimitStatus =
        ref.watch(purchaseLimitStatusProvider(product.id));
    final isAtLimit = purchaseLimitStatus?.isAtLimit ?? false;

    Future<void> add() async {
      final status = ref.read(purchaseLimitStatusProvider(product.id));
      if (status?.isAtLimit ?? false) {
        AppToast.show(context, 'Maximum product order complete');
        return;
      }
      final authGate = ref.read(authGateControllerProvider);
      final allowed = await authGate.protectAddToCart(context, product);
      if (!allowed || !context.mounted) return;
      HapticFeedback.selectionClick();
      final result = await ref
          .read(cartProvider.notifier)
          .addItem(product.id, 1, product: product);
      if (!context.mounted) return;
      if (!result.isSuccess) {
        showCartSnackBar(context, result.failure!.message);
      }
    }

    Future<void> increment() async {
      final status = ref.read(purchaseLimitStatusProvider(product.id));
      if (status?.isAtLimit ?? false) {
        AppToast.show(context, 'Maximum product order complete');
        return;
      }
      HapticFeedback.selectionClick();
      final result = await ref
          .read(cartProvider.notifier)
          .updateItem(product.id, quantity + 1);
      if (!context.mounted) return;
      if (!result.isSuccess) {
        showCartSnackBar(context, result.failure!.message);
      }
    }

    Future<void> decrement() async {
      HapticFeedback.selectionClick();
      final result = quantity == 1
          ? await ref.read(cartProvider.notifier).removeItem(product.id)
          : await ref
              .read(cartProvider.notifier)
              .updateItem(product.id, quantity - 1);
      if (!context.mounted) return;
      if (!result.isSuccess) {
        showCartSnackBar(context, result.failure!.message);
      }
    }

    if (!product.inStock) {
      return const _OutOfStockButton();
    }

    final bool inCart = quantity > 0;

    return Semantics(
      label: inCart ? null : 'Add ${product.name} to cart',
      button: inCart ? null : true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: !inCart
            ? _AddButton(key: const ValueKey<String>('add'), onTap: add)
            : _QuantityStepper(
                key: const ValueKey<String>('stepper'),
                quantity: quantity,
                onIncrement: quantity < 50 && !isAtLimit ? increment : null,
                onDecrement: decrement,
              ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _Palette.ctaRed,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: onTap,
        child: Container(
          width: 44.w,
          height: 44.w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _Palette.ctaRed.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(Icons.add_rounded, size: 27.sp, color: Colors.white),
        ),
      ),
    );
  }
}

class _OutOfStockButton extends StatelessWidget {
  const _OutOfStockButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44.w,
      height: 44.w,
      decoration: BoxDecoration(
        color: _Palette.outOfStockBg,
        borderRadius: BorderRadius.circular(12.r),
      ),
      alignment: Alignment.center,
      child: Text(
        'Out',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: _Palette.outOfStockText,
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    super.key,
  });

  final int quantity;
  final VoidCallback? onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: 96.w,
      height: 44.w,
      decoration: BoxDecoration(
        color: _Palette.ctaRed,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _StepperButton(icon: Icons.remove_rounded, onTap: onDecrement),
          Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          _StepperButton(icon: Icons.add_rounded, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 32.w,
        height: 44.w,
        child: Center(
          child: Icon(
            icon,
            size: 17.sp,
            color: onTap == null
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.white,
          ),
        ),
      ),
    );
  }
}
