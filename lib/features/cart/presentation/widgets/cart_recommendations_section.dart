import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_enhancement_providers.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_misc_widgets.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_pill_tab.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:bakaloo_flutter_app/shared/widgets/product_card.dart';

/// "YOU MAY WANT TO TRY" — the cart's own product-recommendation rail (same
/// `cartQuickAddProductsProvider` mix as before: popular items from
/// categories already in the cart, related categories and a popular
/// fallback). Renders the exact same [ProductCard] (`ProductCardVariant.
/// premiumFresh`, `ProductCardStyle.grid`) the Home screen's Premium Fresh
/// product grid uses — no cart-specific card design — just laid out as a
/// horizontal rail instead of a wrapped grid. Add-to-cart, quantity
/// stepper, multi-option handling, wishlist and stock state all come from
/// that one shared widget, so this section carries none of that logic
/// itself.
class CartRecommendationsSection extends ConsumerStatefulWidget {
  const CartRecommendationsSection({super.key});

  @override
  ConsumerState<CartRecommendationsSection> createState() =>
      _CartRecommendationsSectionState();
}

class _CartRecommendationsSectionState
    extends ConsumerState<CartRecommendationsSection> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(cartQuickAddProductsProvider);

    return productsAsync.when(
      loading: () => const _RecommendationsSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) {
          return const SizedBox.shrink();
        }

        // A real, data-driven second tab — only exists when the mix
        // genuinely contains items the backend flags as sub-10-minute
        // delivery. Never shown as a static/fabricated option.
        final quickPicks = products
            .where(
              (p) => p.hasDeliveryTime && p.displayDeliveryMinutes! <= 10,
            )
            .toList(growable: false);
        final tabs = <String>[
          'Top picks for you',
          if (quickPicks.isNotEmpty) '⚡ Ready in 10 minutes',
        ];
        final selectedIndex = _selectedTab.clamp(0, tabs.length - 1);
        final displayProducts =
            selectedIndex == 1 ? quickPicks : products;

        return Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _SectionTitle(),
                  Gap(12.h),
                  if (tabs.length == 1)
                    SizedBox(
                      width: 168.w,
                      child: CartPillTab(
                        tabs: tabs,
                        selectedIndex: selectedIndex,
                        onTabChanged: (index) =>
                            setState(() => _selectedTab = index),
                      ),
                    )
                  else
                    CartPillTab(
                      tabs: tabs,
                      selectedIndex: selectedIndex,
                      onTabChanged: (index) =>
                          setState(() => _selectedTab = index),
                    ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: EdgeInsets.only(bottom: 16.h),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(left: 16.w, right: 16.w),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final product in displayProducts)
                      Padding(
                        padding: EdgeInsets.only(right: 12.w),
                        child: RepaintBoundary(
                          child: SizedBox(
                            width: 170.w,
                            child: ProductCard(
                              product: product,
                              width: 170,
                              style: ProductCardStyle.grid,
                              variant: ProductCardVariant.premiumFresh,
                              showWishlist: true,
                              onTap: () =>
                                  context.push('/product/${product.id}'),
                              onOptionsTap: product.hasMultipleOptions
                                  ? () =>
                                      showProductOptionsSheet(context, product)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const CartSectionDivider(),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: 'Poppins',
      fontSize: 15.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.3,
      color: Color(0xFF1A1A1A),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        const Text('YOU MAY WANT TO ', style: style),
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            const Text('TRY', style: style),
            Positioned(
              left: 1,
              right: 1,
              bottom: -5.h,
              child: SizedBox(
                height: 7.h,
                child: CustomPaint(painter: _UnderlineSquigglePainter()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A small curved/hand-drawn accent under "TRY" — a shallow quadratic wave,
/// not a straight rule, matching the reference's soft brand-red squiggle.
class _UnderlineSquigglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD02428)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height * 0.75)
      ..quadraticBezierTo(
        size.width * 0.5,
        -size.height * 0.6,
        size.width,
        size.height * 0.75,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RecommendationsSkeleton extends StatelessWidget {
  const _RecommendationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.only(top: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: const _SectionTitle(),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.only(left: 16.w, right: 16.w),
            child: Row(
              children: List<Widget>.generate(
                4,
                (index) => Container(
                  width: 170.w,
                  height: 260.h,
                  margin: EdgeInsets.only(right: 12.w, bottom: 16.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECECEC),
                    borderRadius: BorderRadius.circular(15.r),
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
