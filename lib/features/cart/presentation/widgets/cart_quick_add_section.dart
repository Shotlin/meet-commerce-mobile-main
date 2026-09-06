import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_enhancement_providers.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_misc_widgets.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_pair_with_section.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';

/// "Quick Add" rail — sits below the cart's item list, surfacing products
/// the customer is likely to want given what's already in the cart (see
/// cartQuickAddProductsProvider for the same/related/random-popular mix).
class CartQuickAddSection extends ConsumerWidget {
  const CartQuickAddSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(cartQuickAddProductsProvider);

    return productsAsync.when(
      // Previously rendered nothing at all while loading, so the whole rail
      // (title, "See all", cards) popped into existence abruptly once the
      // network call finished — one more contributor to the cart screen
      // feeling like it "isn't done loading yet" even after everything
      // else settled. A skeleton in the same slot removes that jump: the
      // section is visibly there from the first frame, only the cards
      // themselves swap from placeholders to real content.
      loading: () => const _QuickAddSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) => products.isEmpty
          ? const SizedBox.shrink()
          : Column(
              children: <Widget>[
                ProductRecommendationsStrip(
                  title: 'Quick Add',
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

    // A multi-option product has no inline unit selector on this card —
    // same as the product-detail recommendation rails, route it through
    // the picker sheet instead of guessing which variant to add.
    if (product.hasMultipleOptions) {
      showProductOptionsSheet(context, product);
      return;
    }

    final result = await ref
        .read(cartProvider.notifier)
        .addItem(product.id, 1, product: product);
    if (!context.mounted || result.isSuccess) {
      return;
    }
    showCartSnackBar(context, result.failure!.message);
  }
}

/// Placeholder shown in place of [ProductRecommendationsStrip] while
/// [cartQuickAddProductsProvider] loads — same title/"See all" row (static
/// copy, no reason to wait on it) plus a row of grey card-shaped blocks
/// roughly matching ProductRecommendationCard's own 165.w width so the
/// real cards don't visibly resize the row when they swap in.
class _QuickAddSkeleton extends StatelessWidget {
  const _QuickAddSkeleton();

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
              'Quick Add',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 17.sp,
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
                  width: 165.w,
                  height: 230.h,
                  margin: EdgeInsets.only(right: 12.w, bottom: 16.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECECEC),
                    borderRadius: BorderRadius.circular(12.r),
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
