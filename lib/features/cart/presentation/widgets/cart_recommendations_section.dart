import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_enhancement_providers.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_misc_widgets.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_pill_tab.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';

/// "YOU MAY WANT TO TRY" — the cart's own product-recommendation rail
/// (same `cartQuickAddProductsProvider` mix as before: popular items from
/// categories already in the cart, related categories and a popular
/// fallback), restyled with a dedicated card that mirrors a premium
/// commerce app's recommendation grid: discount badge, floating add
/// button, price row and a delivery-speed line.
class CartRecommendationsSection extends ConsumerWidget {
  const CartRecommendationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(cartQuickAddProductsProvider);

    return productsAsync.when(
      loading: () => const _RecommendationsSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) => products.isEmpty
          ? const SizedBox.shrink()
          : Column(
              children: <Widget>[
                _SectionHeader(products: products),
                _CardRow(
                  products: products,
                  onProductTap: (product) =>
                      context.push('/product/${product.id}'),
                  onAddToCart: (product) => _addToCart(context, ref, product),
                ),
                const CartSectionDivider(),
              ],
            ),
    );
  }

  Future<void> _addToCart(
    BuildContext context,
    WidgetRef ref,
    ProductEntity product,
  ) async {
    if (!product.inStock) {
      showCartSnackBar(context, 'This product is currently unavailable.');
      return;
    }

    if (product.hasMultipleOptions) {
      showProductOptionsSheet(context, product);
      return;
    }

    final result = await ref.read(cartProvider.notifier).addItem(
          product.id,
          1,
          product: product,
          shopProductId: product.shopProductId,
        );
    if (!context.mounted || result.isSuccess) {
      return;
    }
    showCartSnackBar(context, result.failure!.message);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.products});

  final List<ProductEntity> products;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF5F5F5),
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'YOU MAY WANT TO TRY',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          Gap(12.h),
          SizedBox(
            width: 168.w,
            child: const CartPillTab(
              tabs: <String>['Top picks for you'],
              selectedIndex: 0,
              onTabChanged: _noop,
            ),
          ),
        ],
      ),
    );
  }

  static void _noop(int _) {}
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.products,
    this.onProductTap,
    this.onAddToCart,
  });

  final List<ProductEntity> products;
  final ValueChanged<ProductEntity>? onProductTap;
  final ValueChanged<ProductEntity>? onAddToCart;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF5F5F5),
      padding: EdgeInsets.only(bottom: 4.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(left: 16.w, right: 16.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final product in products)
              RepaintBoundary(
                child: CartRecommendationCard(
                  product: product,
                  onTap: onProductTap == null
                      ? null
                      : () => onProductTap!(product),
                  onAdd:
                      onAddToCart == null ? null : () => onAddToCart!(product),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A single recommendation card — image with a top-left discount badge and
/// a floating top-right add/stepper control, then name/pack/price/delivery
/// rows below. Deliberately its own widget (not shared with the product
/// grid or the "Pair it with" rail) so it can match the cart-specific
/// reference layout without perturbing those other surfaces.
class CartRecommendationCard extends ConsumerWidget {
  const CartRecommendationCard({
    required this.product,
    super.key,
    this.onTap,
    this.onAdd,
  });

  final ProductEntity product;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;

  String? get _imageUrl {
    final thumbnail = product.thumbnailUrl?.trim() ?? '';
    if (thumbnail.isNotEmpty) {
      return thumbnail;
    }
    for (final image in product.images) {
      if (image.trim().isNotEmpty) {
        return image;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optimizedImage = ApiConstants.optimizedMedia(
      _imageUrl,
      profile: CustomerImageProfile.listProduct,
    );
    final packInfo = (product.netQuantity?.trim().isNotEmpty ?? false)
        ? product.netQuantity!.trim()
        : product.unit;
    final quantity = product.hasMultipleOptions
        ? 0
        : ref.watch(cartItemQuantityProvider(product.id));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 152.w,
        margin: EdgeInsets.only(right: 12.w, bottom: 12.h),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEDEDED)),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              height: 128.h,
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(14.r),
                      ),
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: Color(0xFFFAFAFA),
                        ),
                        child: _imageUrl == null
                            ? Center(
                                child: PhosphorIcon(
                                  PhosphorIcons.image,
                                  size: 26.sp,
                                  color: const Color(0xFFBBBBBB),
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: optimizedImage.url ?? _imageUrl!,
                                fit: BoxFit.cover,
                                memCacheWidth: optimizedImage.memCacheWidth,
                                memCacheHeight: optimizedImage.memCacheHeight,
                                fadeInDuration: Duration.zero,
                                filterQuality: FilterQuality.high,
                                errorWidget: (context, url, error) => Center(
                                  child: PhosphorIcon(
                                    PhosphorIcons.imageBroken,
                                    size: 22.sp,
                                    color: const Color(0xFFBBBBBB),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  if (product.discountPercent > 0)
                    Positioned(
                      top: 8.h,
                      left: 8.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          '${product.discountPercent}% OFF',
                          style: TextStyle(
                            fontSize: 9.5.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                  if (!product.inStock)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.55),
                        alignment: Alignment.center,
                        child: Text(
                          'Out of stock',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    )
                  else
                    Positioned(
                      right: 6.w,
                      bottom: -14.h,
                      child: quantity > 0
                          ? _StepperPill(
                              quantity: quantity,
                              onDecrease: () => _updateQuantity(
                                context,
                                ref,
                                quantity - 1,
                              ),
                              onIncrease: () => _updateQuantity(
                                context,
                                ref,
                                quantity + 1,
                              ),
                            )
                          : _AddButton(onTap: onAdd),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 20.h, 10.w, 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF222222),
                      height: 1.25,
                      fontFamily: 'Inter',
                    ),
                  ),
                  Gap(4.h),
                  Text(
                    packInfo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF888888),
                      fontFamily: 'Inter',
                    ),
                  ),
                  Gap(6.h),
                  Row(
                    children: <Widget>[
                      Text(
                        '₹${product.effectivePrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1A1A),
                          fontFamily: 'Inter',
                        ),
                      ),
                      if (product.discountPercent > 0) ...<Widget>[
                        Gap(6.w),
                        Text(
                          '₹${product.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF999999),
                            decoration: TextDecoration.lineThrough,
                            decorationColor: const Color(0xFF999999),
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (product.hasDeliveryTime) ...<Widget>[
                    Gap(5.h),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.bolt_rounded,
                          size: 12.sp,
                          color: const Color(0xFF0AC26B),
                        ),
                        Gap(2.w),
                        Flexible(
                          child: Text(
                            'Today in ${product.formattedDeliveryTime}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF0AC26B),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateQuantity(
    BuildContext context,
    WidgetRef ref,
    int quantity,
  ) async {
    final notifier = ref.read(cartProvider.notifier);
    final result = quantity <= 0
        ? await notifier.removeItem(product.id)
        : await notifier.updateItem(product.id, quantity);
    if (!context.mounted || result.isSuccess) {
      return;
    }
    showCartSnackBar(context, result.failure!.message);
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 60.w,
        height: 28.h,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.brandRed, width: 1.4),
          borderRadius: BorderRadius.circular(8.r),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          'ADD',
          style: TextStyle(
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.brandRed,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }
}

class _StepperPill extends StatelessWidget {
  const _StepperPill({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28.h,
      decoration: BoxDecoration(
        color: AppColors.brandRed,
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDecrease,
            child: SizedBox(
              width: 22.w,
              height: double.infinity,
              child: Icon(Icons.remove_rounded, size: 14.sp, color: Colors.white),
            ),
          ),
          Text(
            '$quantity',
            style: TextStyle(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onIncrease,
            child: SizedBox(
              width: 22.w,
              height: double.infinity,
              child: Icon(Icons.add_rounded, size: 14.sp, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationsSkeleton extends StatelessWidget {
  const _RecommendationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF5F5F5),
      padding: EdgeInsets.only(top: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Text(
              'YOU MAY WANT TO TRY',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.only(left: 16.w, right: 16.w),
            child: Row(
              children: List<Widget>.generate(
                4,
                (index) => Container(
                  width: 152.w,
                  height: 230.h,
                  margin: EdgeInsets.only(right: 12.w, bottom: 16.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECECEC),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
