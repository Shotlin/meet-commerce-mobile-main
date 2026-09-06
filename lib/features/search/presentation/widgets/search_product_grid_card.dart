import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/presentation/providers/purchase_limits_provider.dart';
import 'package:bakaloo_flutter_app/features/wishlist/presentation/providers/wishlist_provider.dart';

// FreshCuts brand system for this card — kept local rather than pulled from
// AppColors since these are exact tokens from the search-results design spec
// (a strong CTA red distinct from the softer brandRed used elsewhere).
class _Palette {
  _Palette._();
  static const Color brandRed = Color(0xFFC32D2E);
  static const Color ctaRed = Color(0xFFE51F2A);
  static const Color textMain = Color(0xFF111318);
  static const Color textSecondary = Color(0xFF6F7785);
  static const Color border = Color(0xFFECEEF2);
  static const Color surface = Color(0xFFF7F8FA);
  static const Color discountGreen = Color(0xFF11883E);
}

/// Product card for the search-results grid — image with tag/wishlist
/// overlay, name, subtitle, a weight chip and a price + add-to-cart row.
///
/// Wired to the same cart/wishlist/purchase-limit/auth-gate providers as
/// the rest of the app, so Add/quantity/wishlist behave identically to
/// every other product surface.
class SearchProductGridCard extends ConsumerWidget {
  const SearchProductGridCard({required this.product, super.key});

  final ProductEntity product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = product.thumbnailUrl ??
        (product.images.isNotEmpty ? product.images.first : null);
    final tag = product.customBadges.isNotEmpty
        ? product.customBadges.first
        : (product.tags.isNotEmpty ? product.tags.first : null);

    return InkWell(
      onTap: () => context.push('/product/${product.id}'),
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: _Palette.border),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _ImageArea(product: product, imageUrl: imageUrl, tag: tag),
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15.5.sp,
                      fontWeight: FontWeight.w700,
                      color: _Palette.textMain,
                      height: 1.2,
                    ),
                  ),
                  if (product.brandDisplay.isNotEmpty) ...<Widget>[
                    Gap(3.h),
                    Text(
                      product.brandDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w400,
                        color: _Palette.textSecondary,
                      ),
                    ),
                  ],
                  Gap(8.h),
                  _WeightChip(product: product),
                  Gap(8.h),
                  _PriceAndAddRow(product: product),
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
  const _ImageArea({
    required this.product,
    required this.imageUrl,
    required this.tag,
  });

  final ProductEntity product;
  final String? imageUrl;
  final String? tag;

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

    return AspectRatio(
      aspectRatio: 1.22,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ColoredBox(
            color: _Palette.surface,
            child: imageUrl == null || imageUrl!.isEmpty
                ? Center(
                    child: PhosphorIcon(
                      PhosphorIcons.image,
                      color: _Palette.textSecondary,
                      size: 32.sp,
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    errorWidget: (_, __, ___) => Center(
                      child: PhosphorIcon(
                        PhosphorIcons.imageBroken,
                        color: _Palette.textSecondary,
                        size: 32.sp,
                      ),
                    ),
                  ),
          ),
          if (tag != null)
            Positioned(
              top: 10.h,
              left: 10.w,
              child: _ProductTag(label: tag!),
            ),
          Positioned(
            top: 8.h,
            right: 8.w,
            child: _WishlistHeartButton(
              product: product,
              isWishlisted: isWishlisted,
            ),
          ),
          if (!product.inStock)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
                alignment: Alignment.center,
                child: Text(
                  'Out of stock',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductTag extends StatelessWidget {
  const _ProductTag({required this.label});

  final String label;

  bool get _isFreshVariant => label.toLowerCase().contains('fresh');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: _isFreshVariant ? _Palette.discountGreen : _Palette.ctaRed,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w700,
          color: Colors.white,
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
    return Material(
      color: Colors.white,
      shape: CircleBorder(side: BorderSide(color: _Palette.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async {
          final authGate = ref.read(authGateControllerProvider);
          final allowed = await authGate.protectWishlist(context, product);
          if (!allowed || !context.mounted) return;
          final result =
              await ref.read(wishlistProvider.notifier).toggleWishlist(product);
          if (!context.mounted || result.isSuccess) return;
          AppToast.show(context, result.failure!.message);
        },
        child: SizedBox(
          width: 36.w,
          height: 36.w,
          child: Center(
            child: PhosphorIcon(
              isWishlisted ? PhosphorIcons.heartFill : PhosphorIcons.heart,
              size: 18.sp,
              color: _Palette.ctaRed,
            ),
          ),
        ),
      ),
    );
  }
}

/// Displays the product's unit as a single chip. Real search results only
/// carry the option the user is currently viewing — picking a different
/// weight is a different product record (`hasMultipleOptions`), so a tap
/// opens the existing product-options sheet rather than faking an inline
/// price swap the data can't back up.
class _WeightChip extends StatelessWidget {
  const _WeightChip({required this.product});

  final ProductEntity product;

  @override
  Widget build(BuildContext context) {
    final label = product.displayUnit.trim().isNotEmpty
        ? product.displayUnit
        : product.unit;

    return GestureDetector(
      onTap: product.hasMultipleOptions
          ? () => showProductOptionsSheet(context, product)
          : null,
      child: Container(
        height: 34.h,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: _Palette.brandRed),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
                color: _Palette.brandRed,
              ),
            ),
            if (product.hasMultipleOptions) ...<Widget>[
              Gap(3.w),
              PhosphorIcon(
                PhosphorIcons.caretDownBold,
                size: 11.sp,
                color: _Palette.brandRed,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PriceAndAddRow extends StatelessWidget {
  const _PriceAndAddRow({required this.product});

  final ProductEntity product;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6.w,
            children: <Widget>[
              Text(
                '₹${product.effectivePrice.toStringAsFixed(0)}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w800,
                  color: _Palette.textMain,
                ),
              ),
              if (product.isOnSale)
                Text(
                  '₹${product.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8B93A0),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
        ),
        Gap(6.w),
        _AddToCartControl(product: product),
      ],
    );
  }
}

/// The "Add" CTA that morphs into a [-] qty [+] stepper in the same
/// footprint once the item is in the cart — mirrors the rest of the app's
/// cart mutation flow (auth gate + purchase-limit re-check on every tap).
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
      final result = await ref
          .read(cartProvider.notifier)
          .updateItem(product.id, quantity + 1);
      if (!context.mounted) return;
      if (!result.isSuccess) {
        showCartSnackBar(context, result.failure!.message);
      }
    }

    Future<void> decrement() async {
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

    final bool inCart = quantity > 0;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: !inCart
          ? _AddButton(
              key: const ValueKey<String>('add'),
              enabled: product.inStock,
              onTap: add,
            )
          : _QuantityStepper(
              key: const ValueKey<String>('stepper'),
              quantity: quantity,
              onIncrement: product.inStock && quantity < 50 && !isAtLimit
                  ? increment
                  : null,
              onDecrement: decrement,
            ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.enabled, required this.onTap, super.key});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? _Palette.ctaRed : _Palette.textSecondary,
      borderRadius: BorderRadius.circular(13.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(13.r),
        onTap: enabled ? onTap : null,
        child: Container(
          height: 44.h,
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PhosphorIcon(
                PhosphorIcons.shoppingCartBold,
                size: 15.sp,
                color: Colors.white,
              ),
              Gap(5.w),
              Text(
                'Add',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
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
    return Container(
      height: 44.h,
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      decoration: BoxDecoration(
        color: _Palette.ctaRed,
        borderRadius: BorderRadius.circular(13.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StepperButton(icon: PhosphorIcons.minusBold, onTap: onDecrement),
          SizedBox(
            width: 26.w,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          _StepperButton(icon: PhosphorIcons.plusBold, onTap: onIncrement),
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
        width: 26.w,
        height: 44.h,
        child: Center(
          child: PhosphorIcon(
            icon,
            size: 14.sp,
            color: onTap == null
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.white,
          ),
        ),
      ),
    );
  }
}
