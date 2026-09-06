import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/presentation/providers/purchase_limits_provider.dart';
import 'package:bakaloo_flutter_app/features/wishlist/presentation/providers/wishlist_provider.dart';
import 'package:bakaloo_flutter_app/shared/widgets/safe_product_image.dart';

/// Real category buckets are derived from whichever categories the
/// wishlisted products actually belong to (product.categoryName) — never a
/// fixed hardcoded list, so this stays correct as the catalog grows.
const String _kAllCategoryKey = 'All';
const String _kUncategorizedLabel = 'Others';

class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  String _selectedCategory = _kAllCategoryKey;
  bool _isManaging = false;
  final Set<String> _selectedForRemoval = <String>{};

  @override
  Widget build(BuildContext context) {
    final wishlistAsync = ref.watch(wishlistProvider);
    final cartCount = ref.watch(cartCountProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFE),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
              child: Row(
                children: <Widget>[
                  GestureDetector(
                    onTap: () =>
                        context.canPop() ? context.pop() : context.go('/'),
                    child: Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        size: 20.sp,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Image.asset(
                      'assets/images/freshcuts-logo-wordmark.png',
                      height: 32.h,
                      fit: BoxFit.contain,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/cart'),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Container(
                          width: 40.w,
                          height: 40.w,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.shopping_cart_outlined,
                            size: 20.sp,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        if (cartCount > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 5.w,
                                vertical: 1.h,
                              ),
                              constraints: BoxConstraints(minWidth: 18.w),
                              decoration: const BoxDecoration(
                                color: AppColors.brandRed,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$cartCount',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: wishlistAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.brandRed),
                ),
                error: (error, _) => _WishlistErrorState(
                  message: error.toString().replaceFirst('Bad state: ', ''),
                  onRetry: () => ref.invalidate(wishlistProvider),
                ),
                data: (wishlistData) {
                  if (wishlistData.items.isEmpty) {
                    return const _WishlistEmptyState();
                  }

                  // Piggybacks on the wishlist fetch that's already
                  // happening — no extra per-card network call.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref
                        .read(purchaseLimitsNotifierProvider.notifier)
                        .ensureLoaded(
                          wishlistData.items
                              .map((item) => item.product.id)
                              .toList(),
                        );
                  });

                  final categoryCounts = <String, int>{};
                  for (final item in wishlistData.items) {
                    final key =
                        item.product.categoryName?.trim().isNotEmpty == true
                            ? item.product.categoryName!.trim()
                            : _kUncategorizedLabel;
                    categoryCounts[key] = (categoryCounts[key] ?? 0) + 1;
                  }
                  final categories = categoryCounts.keys.toList()..sort();

                  final filteredItems = _selectedCategory == _kAllCategoryKey
                      ? wishlistData.items
                      : wishlistData.items.where((item) {
                          final key =
                              item.product.categoryName?.trim().isNotEmpty ==
                                      true
                                  ? item.product.categoryName!.trim()
                                  : _kUncategorizedLabel;
                          return key == _selectedCategory;
                        }).toList();

                  return RefreshIndicator(
                    color: AppColors.brandRed,
                    onRefresh: () async {
                      ref.read(wishlistProvider.notifier).refresh();
                      await ref.read(wishlistProvider.future);
                    },
                    child: Column(
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'My Wishlist',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 24.sp,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF1A1A1A),
                                      ),
                                    ),
                                    Gap(3.h),
                                    Text(
                                      'Your favorite products, anytime.',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12.5.sp,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_isManaging) ...<Widget>[
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isManaging = false;
                                      _selectedForRemoval.clear();
                                    });
                                  },
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ] else
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _isManaging = true),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 14.w,
                                      vertical: 9.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20.r),
                                      border: Border.all(
                                        color: const Color(0xFFE5E5E5),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Icon(
                                          Icons.checklist_rtl,
                                          size: 16.sp,
                                          color: const Color(0xFF1A1A1A),
                                        ),
                                        Gap(6.w),
                                        Text(
                                          'Manage',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12.5.sp,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1A1A1A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Gap(14.h),
                        SizedBox(
                          height: 38.h,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            itemCount: categories.length + 1,
                            separatorBuilder: (_, __) => Gap(8.w),
                            itemBuilder: (context, index) {
                              final String key = index == 0
                                  ? _kAllCategoryKey
                                  : categories[index - 1];
                              final int count = index == 0
                                  ? wishlistData.items.length
                                  : categoryCounts[key]!;
                              final bool selected = _selectedCategory == key;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedCategory = key),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.brandRed
                                        : const Color(0xFFEFEFF2),
                                    borderRadius: BorderRadius.circular(20.r),
                                  ),
                                  child: Text(
                                    '$key ($count)',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12.5.sp,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFF444444),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Gap(8.h),
                        Expanded(
                          child: ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              16.w,
                              8.h,
                              16.w,
                              16.h,
                            ),
                            itemCount: filteredItems.length,
                            separatorBuilder: (_, __) => Gap(12.h),
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              return _WishlistRow(
                                product: item.product,
                                isManaging: _isManaging,
                                isSelected: _selectedForRemoval
                                    .contains(item.product.id),
                                onSelectToggle: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedForRemoval.add(item.product.id);
                                    } else {
                                      _selectedForRemoval
                                          .remove(item.product.id);
                                    }
                                  });
                                },
                                onRemove: () async {
                                  await ref
                                      .read(wishlistProvider.notifier)
                                      .toggleWishlist(item.product);
                                },
                                onAddToCart: () async {
                                  final result = await ref
                                      .read(cartProvider.notifier)
                                      .addItem(
                                        item.product.id,
                                        1,
                                        product: item.product,
                                      );
                                  if (!context.mounted) return;
                                  if (!result.isSuccess &&
                                      result.failure != null) {
                                    AppToast.show(
                                      context,
                                      result.failure!.message,
                                    );
                                  } else {
                                    AppToast.show(
                                      context,
                                      '${item.product.name} added to cart',
                                      type: ToastType.success,
                                    );
                                  }
                                },
                                onTap: item.product.hasMultipleOptions
                                    ? () => showProductOptionsSheet(
                                          context,
                                          item.product,
                                        )
                                    : () => context
                                        .push('/product/${item.product.id}'),
                              );
                            },
                          ),
                        ),
                        if (_isManaging && _selectedForRemoval.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
                            child: SizedBox(
                              width: double.infinity,
                              child: Material(
                                color: AppColors.outOfStockRed,
                                borderRadius: BorderRadius.circular(28.r),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(28.r),
                                  onTap: () async {
                                    final toRemove = wishlistData.items
                                        .where(
                                          (i) => _selectedForRemoval
                                              .contains(i.product.id),
                                        )
                                        .map((i) => i.product)
                                        .toList(growable: false);
                                    setState(() {
                                      _isManaging = false;
                                      _selectedForRemoval.clear();
                                    });
                                    for (final product in toRemove) {
                                      await ref
                                          .read(wishlistProvider.notifier)
                                          .toggleWishlist(product);
                                    }
                                  },
                                  child: Container(
                                    height: 48.h,
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Remove Selected '
                                      '(${_selectedForRemoval.length})',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          _WishlistBottomBar(
                            itemCount: wishlistData.items.length,
                            onAddAllToCart: () async {
                              final result = await ref
                                  .read(wishlistProvider.notifier)
                                  .moveAllToCart();
                              if (!context.mounted) return;
                              AppToast.show(
                                context,
                                result.isSuccess
                                    ? '${result.movedCount} items moved to cart.'
                                    : result.failure!.message,
                                type: result.isSuccess
                                    ? ToastType.success
                                    : ToastType.warning,
                              );
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistRow extends StatelessWidget {
  const _WishlistRow({
    required this.product,
    required this.isManaging,
    required this.isSelected,
    required this.onSelectToggle,
    required this.onRemove,
    required this.onAddToCart,
    required this.onTap,
  });

  final ProductEntity product;
  final bool isManaging;
  final bool isSelected;
  final ValueChanged<bool> onSelectToggle;
  final VoidCallback onRemove;
  final VoidCallback onAddToCart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool outOfStock = !product.inStock;
    final bool lowStock = product.lowStock;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Padding(
          padding: EdgeInsets.all(10.w),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Image fills the row's full height (set by the text
                // column next to it via IntrinsicHeight) — no leftover
                // blank strip below a short, fixed-size thumbnail.
                ClipRRect(
                  borderRadius: BorderRadius.circular(14.r),
                  child: SizedBox(
                    width: 100.w,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        _StretchedProductImage(url: product.thumbnailUrl),
                        if (outOfStock)
                          Container(color: const Color(0x99FFFFFF)),
                        Positioned(
                          top: 6.h,
                          right: 6.w,
                          child: GestureDetector(
                            onTap: isManaging ? null : onRemove,
                            child: Container(
                              width: 26.w,
                              height: 26.w,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Color(0x1F000000),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.favorite,
                                size: 14.sp,
                                color: AppColors.brandRed,
                              ),
                            ),
                          ),
                        ),
                        if (!isManaging)
                          Positioned(
                            right: 6.w,
                            bottom: 6.h,
                            child: Material(
                              color: outOfStock
                                  ? const Color(0xFFBBBBBB)
                                  : AppColors.brandRed,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: outOfStock ? null : onAddToCart,
                                child: SizedBox(
                                  width: 28.w,
                                  height: 28.w,
                                  child: Icon(
                                    Icons.add,
                                    size: 18.sp,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Gap(12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          if (product.brandDisplay.isNotEmpty) ...<Widget>[
                            Gap(2.h),
                            Text(
                              product.brandDisplay,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5.sp,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          Gap(8.h),
                          Wrap(
                            spacing: 6.w,
                            runSpacing: 6.h,
                            children: <Widget>[
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 3.h,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F0F0),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  product.displayUnit,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10.5.sp,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF555555),
                                  ),
                                ),
                              ),
                              _StockPill(
                                outOfStock: outOfStock,
                                lowStock: lowStock,
                                stockQuantity: product.stockQuantity,
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: <Widget>[
                          Text(
                            product.effectivePrice.toInrCurrency,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          if (product.isOnSale) ...<Widget>[
                            Gap(6.w),
                            Text(
                              product.price.toInrCurrency,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5.sp,
                                color: AppColors.textTertiary,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (isManaging)
                            GestureDetector(
                              onTap: () => onSelectToggle(!isSelected),
                              child: Container(
                                width: 26.w,
                                height: 26.w,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.outOfStockRed
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.outOfStockRed
                                        : const Color(0xFFCCCCCC),
                                    width: 1.4,
                                  ),
                                ),
                                child: isSelected
                                    ? Icon(
                                        Icons.check,
                                        size: 16.sp,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ],
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

/// A product image that fills whatever height its parent [Stack] gives it
/// (via the row's [IntrinsicHeight]) rather than [SafeProductImage]'s fixed
/// square — this card's image is deliberately taller than it is wide.
/// Mirrors SafeProductImage's own URL-validation + placeholder/error
/// fallback so a bad thumbnail still degrades to a neutral tile instead of
/// a broken-image icon.
class _StretchedProductImage extends StatelessWidget {
  const _StretchedProductImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (!isSafeImageUrl(url)) {
      return const _StretchedImageFallback();
    }
    return CachedNetworkImage(
      imageUrl: url!.trim(),
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, __) => const _StretchedImageFallback(),
      errorWidget: (_, __, ___) => const _StretchedImageFallback(),
    );
  }
}

class _StretchedImageFallback extends StatelessWidget {
  const _StretchedImageFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.orderThumbBg,
      child: Center(
        child: PhosphorIcon(
          PhosphorIcons.package,
          size: 22.sp,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _StockPill extends StatelessWidget {
  const _StockPill({
    required this.outOfStock,
    required this.lowStock,
    required this.stockQuantity,
  });

  final bool outOfStock;
  final bool lowStock;
  final int stockQuantity;

  @override
  Widget build(BuildContext context) {
    final String label = outOfStock
        ? 'Out of Stock'
        : lowStock
            ? 'Only $stockQuantity left'
            : 'In Stock';
    final Color color = outOfStock
        ? AppColors.outOfStockRed
        : lowStock
            ? AppColors.warningOrange
            : AppColors.successGreen;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Gap(4.w),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _WishlistBottomBar extends StatelessWidget {
  const _WishlistBottomBar({
    required this.itemCount,
    required this.onAddAllToCart,
  });

  final int itemCount;
  final VoidCallback onAddAllToCart;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0x14000000),
            blurRadius: 20.r,
            offset: Offset(0, -4.h),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40.w,
            height: 40.w,
            decoration: const BoxDecoration(
              color: AppColors.brandRedSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite,
              size: 18.sp,
              color: AppColors.brandRed,
            ),
          ),
          Gap(10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '$itemCount item${itemCount == 1 ? '' : 's'} in your wishlist',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  'Move to cart and enjoy fresh savings!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Gap(10.w),
          Material(
            color: AppColors.brandRed,
            borderRadius: BorderRadius.circular(24.r),
            child: InkWell(
              borderRadius: BorderRadius.circular(24.r),
              onTap: onAddAllToCart,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 16.sp,
                      color: Colors.white,
                    ),
                    Gap(6.w),
                    Text(
                      'Add All to Cart',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WishlistEmptyState extends StatelessWidget {
  const _WishlistEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 160.w,
              height: 160.w,
              child: Lottie.network(
                'https://assets4.lottiefiles.com/packages/lf20_lj9x0wdj.json',
                repeat: true,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  PhosphorIcons.heart,
                  size: 80.sp,
                  color: AppColors.textDisabled,
                ),
              ),
            ),
            Gap(12.h),
            Text(
              'Your wishlist is empty',
              style: AppTextStyles.h3,
            ),
            Gap(6.h),
            Text(
              'Tap the heart icon on products to save them here.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistErrorState extends StatelessWidget {
  const _WishlistErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            Gap(10.h),
            FilledButton(
              onPressed: onRetry,
              child: Text('Retry', style: AppTextStyles.buttonMedium),
            ),
          ],
        ),
      ),
    );
  }
}
