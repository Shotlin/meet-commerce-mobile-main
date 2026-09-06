import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_enhancement_providers.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_product_cards.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/providers/banner_provider.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';

class CartLastMinuteSection extends ConsumerWidget {
  const CartLastMinuteSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(lastMinuteProductsProvider);

    return productsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) {
          return const SizedBox.shrink();
        }

        return RepaintBoundary(
          child: _SectionShell(
            title: Row(
              children: <Widget>[
                Text(
                  'café',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF222222),
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(width: 10.w),
                Text(
                  'Last-minute cravings?',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF222222),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
            child: SizedBox(
              height: 280.h,
              child: ListView.builder(
                clipBehavior: Clip.none,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                scrollDirection: Axis.horizontal,
                itemExtent: 152.w,
                itemCount: products.length,
                itemBuilder: (_, index) {
                  final product = products[index];
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: EdgeInsets.only(right: 12.w),
                      child: CartProductCardGreen(
                        name: product['name']?.toString() ?? '',
                        price: _asDouble(product['price']),
                        salePrice: _nullableDouble(product['sale_price']),
                        imageUrl: product['thumbnail_url']?.toString(),
                        onAddTap: () => _addMapProduct(ref, product),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class CartPriceDropSection extends ConsumerStatefulWidget {
  const CartPriceDropSection({super.key});

  @override
  ConsumerState<CartPriceDropSection> createState() =>
      _CartPriceDropSectionState();
}

class _CartPriceDropSectionState extends ConsumerState<CartPriceDropSection> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(priceDropProductsProvider);

    return productsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) {
          return const SizedBox.shrink();
        }

        final filtered = _selectedTab == 0
            ? products
            : products
                .where(
                  (product) => _effectivePriceFromMap(product) <= 99,
                )
                .toList(growable: false);

        final displayProducts = filtered.isEmpty ? products : filtered;

        return RepaintBoundary(
          child: _SectionShell(
            title: Row(
              children: <Widget>[
                Text(
                  'Price Drop Alert',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF222222),
                    fontFamily: 'Inter',
                  ),
                ),
                const Spacer(),
                _PriceToggleChip(
                  label: 'Top deals',
                  selected: _selectedTab == 0,
                  onTap: () => setState(() => _selectedTab = 0),
                ),
                SizedBox(width: 8.w),
                _PriceToggleChip(
                  label: 'Under ₹99',
                  selected: _selectedTab == 1,
                  onTap: () => setState(() => _selectedTab = 1),
                ),
              ],
            ),
            child: SizedBox(
              height: 280.h,
              child: ListView.builder(
                clipBehavior: Clip.none,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                scrollDirection: Axis.horizontal,
                itemExtent: 152.w,
                itemCount: displayProducts.length,
                itemBuilder: (_, index) {
                  final product = displayProducts[index];
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: EdgeInsets.only(right: 12.w),
                      child: CartProductCardGreen(
                        name: product['name']?.toString() ?? '',
                        price: _asDouble(product['price']),
                        salePrice: _nullableDouble(product['sale_price']),
                        imageUrl: product['thumbnail_url']?.toString(),
                        onAddTap: () => _addMapProduct(ref, product),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class CartYouMightAlsoLikeSection extends ConsumerWidget {
  const CartYouMightAlsoLikeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredAsync = ref.watch(homeFeaturedProductsProvider);

    return featuredAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) {
          return const SizedBox.shrink();
        }

        return RepaintBoundary(
          child: _SectionShell(
            title: Row(
              children: <Widget>[
                Text(
                  'You might also like 💕',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF222222),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
            child: SizedBox(
              height: 280.h,
              child: ListView.builder(
                clipBehavior: Clip.none,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                scrollDirection: Axis.horizontal,
                itemExtent: 152.w,
                itemCount: products.length.clamp(0, 6).toInt(),
                itemBuilder: (_, index) {
                  final product = products[index];
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: EdgeInsets.only(right: 12.w),
                      child: CartProductCardRed(
                        name: product.name,
                        price: product.price,
                        salePrice: product.salePrice,
                        imageUrl: product.thumbnailUrl,
                        onAddTap: () => _addEntityProduct(ref, product),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.child,
  });

  final Widget title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(top: 16.h, bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: title,
          ),
          SizedBox(height: 14.h),
          child,
        ],
      ),
    );
  }
}

class _PriceToggleChip extends StatelessWidget {
  const _PriceToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEDF9F2) : const Color(0xFFF6F6F6),
          borderRadius: BorderRadius.circular(999.r),
          border: Border.all(
            color: selected ? const Color(0xFF0AC26B) : const Color(0xFFE3E3E3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF0AC26B) : const Color(0xFF666666),
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }
}

void _addMapProduct(WidgetRef ref, Map<String, dynamic> product) {
  final id = product['id']?.toString();
  if (id == null || id.isEmpty) {
    return;
  }

  ref.read(cartProvider.notifier).addItem(id, 1);
}

void _addEntityProduct(WidgetRef ref, ProductEntity product) {
  ref.read(cartProvider.notifier).addItem(product.id, 1, product: product);
}

double _asDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _nullableDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  return _asDouble(value);
}

double _effectivePriceFromMap(Map<String, dynamic> product) {
  final price = _asDouble(product['price']);
  final salePrice = _nullableDouble(product['sale_price']);
  if (salePrice != null && salePrice > 0 && salePrice < price) {
    return salePrice;
  }
  return price;
}
