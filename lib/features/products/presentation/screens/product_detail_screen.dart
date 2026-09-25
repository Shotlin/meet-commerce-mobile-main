import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:bakaloo_flutter_app/core/analytics/analytics_service.dart';
import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/product_detail_provider.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/presentation/providers/purchase_limits_provider.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/recently_viewed_provider.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/screens/product_detail_compat.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/screens/product_detail_socket_delegate.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/screens/product_list_screen.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_bottom_bar.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_detail_loading_view.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_details_section.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_detail_tabs.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_delivery_banner.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_image_gallery.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_info_header.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_quality_grid.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_quantity_row.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_recommendation_wrappers.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_store_row.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_thumbnail_strip.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_trust_badges.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_variant_selector.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/product_vendor_section.dart';
import 'package:bakaloo_flutter_app/features/wishlist/presentation/providers/wishlist_ids_provider.dart';
import 'package:bakaloo_flutter_app/features/wishlist/presentation/providers/wishlist_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/widgets/error_state.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({
    required this.id,
    super.key,
  });

  final String id;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  late final ScrollController _scrollController;
  late final PageController _galleryPageController;
  late ProductDetailSocketDelegate _socketDelegate;
  bool _isAppBarCollapsed = false;
  bool _hasReachedRecommendations = false;
  bool _hasLoggedView = false;
  int _currentImageIndex = 0;
  // Which family member is currently displayed. Starts as widget.id but can
  // be swapped in place via the "Select Unit" chip row (product_variant_
  // selector.dart) without a route change — see _selectVariant.
  late String _selectedProductId;

  @override
  void initState() {
    super.initState();
    _selectedProductId = widget.id;
    _scrollController = ScrollController()..addListener(_onScroll);
    _galleryPageController = PageController();
    _socketDelegate = _createSocketDelegate();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _galleryPageController.dispose();
    _socketDelegate.dispose();
    super.dispose();
  }

  ProductDetailSocketDelegate _createSocketDelegate() {
    return ProductDetailSocketDelegate(
      ref: ref,
      productId: _selectedProductId,
      onProductDataChanged: _refreshProductData,
      onCartChanged: () => ref.read(cartProvider.notifier).refresh(),
    )..setup();
  }

  // The socket delegate filters live stock/price events by a fixed
  // productId set at construction time, so swapping variants needs a fresh
  // delegate bound to the newly selected id — otherwise socket pushes for
  // the new variant would be silently ignored.
  void _selectVariant(String productId) {
    if (productId == _selectedProductId) {
      return;
    }
    _socketDelegate.dispose();
    if (_galleryPageController.hasClients) {
      _galleryPageController.jumpToPage(0);
    }
    setState(() {
      _selectedProductId = productId;
      _hasLoggedView = false;
      _currentImageIndex = 0;
    });
    _socketDelegate = _createSocketDelegate();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final offset = _scrollController.offset;
    final collapsed = offset > 240;
    final reachedRecommendations = offset >= 180;
    if (collapsed != _isAppBarCollapsed ||
        reachedRecommendations != _hasReachedRecommendations) {
      setState(() {
        _isAppBarCollapsed = collapsed;
        _hasReachedRecommendations = reachedRecommendations;
      });
    }
  }

  void _refreshProductData() {
    ref
      ..invalidate(productDetailProvider(_selectedProductId))
      ..invalidate(pairWithProductsProvider(_selectedProductId))
      ..invalidate(relatedProductsProvider(_selectedProductId));
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailProvider(_selectedProductId));

    return productAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: ProductDetailLoadingView(),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: ErrorState(
          message: error.toString().replaceFirst('Bad state: ', ''),
          onRetry: _refreshProductData,
        ),
      ),
      data: (product) {
        final effectiveProduct = normalizedProductForDetail(product);
        final effectiveAttributes = effectiveAttributesForDetail(
          effectiveProduct,
        );
        final cartQty =
            ref.watch(cartItemQuantityProvider(effectiveProduct.id));
        // Purchase-limits: null == unrestricted (the common case, zero
        // extra visual/logic changes).
        final purchaseLimitStatus =
            ref.watch(purchaseLimitStatusProvider(effectiveProduct.id));
        final isAtPurchaseLimit = purchaseLimitStatus?.isAtLimit ?? false;

        // Piggybacks on the product detail fetch that's already happening —
        // no extra per-card network call. Cheap no-op when already known.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref
              .read(purchaseLimitsNotifierProvider.notifier)
              .ensureLoaded(<String>[effectiveProduct.id]);
        });

        if (!_hasLoggedView) {
          _hasLoggedView = true;
          unawaited(
            ref.read(analyticsServiceProvider).logProductView(
                  effectiveProduct.id,
                  effectiveProduct.categoryId,
                ),
          );
          unawaited(
            ref
                .read(recentlyViewedProvider.notifier)
                .recordView(effectiveProduct.id),
          );
        }

        // The gallery photo up top can be light-toned (wood/plant lifestyle
        // shots), which made the platform-default light status bar icons
        // (white time/battery/signal) unreadable against it — force dark
        // icons here regardless of collapsed state, matching the pattern
        // already used on the Home screen.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: AppColors.bgPrimary,
            body: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: <Widget>[
                ProductImageGallery(
                  images: effectiveProduct.images,
                  thumbnailUrl: effectiveProduct.thumbnailUrl,
                  productName: effectiveProduct.name,
                  price: effectiveProduct.price,
                  salePrice: effectiveProduct.salePrice,
                  avgRating: effectiveProduct.avgRating,
                  ratingCount: effectiveProduct.ratingCount,
                  highlights: effectiveProduct.highlights,
                  isCollapsed: _isAppBarCollapsed,
                  isWishlisted: ref.watch(
                    wishlistIdsProvider
                        .select((ids) => ids.contains(effectiveProduct.id)),
                  ),
                  onWishlistToggle: () => _toggleWishlist(effectiveProduct),
                  pageController: _galleryPageController,
                  onSearch: _navigateToSearch,
                  onShare: () => _shareProduct(effectiveProduct),
                  onBack: _handleBack,
                  onImageChanged: (index) {
                    setState(() => _currentImageIndex = index);
                    _logProductImageSwipe(effectiveProduct, index);
                  },
                  onHighlightsToggle: () => _logProductHighlightsView(
                    effectiveProduct,
                  ),
                ),
                SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: ProductThumbnailStrip(
                      images: effectiveProduct.images,
                      selectedIndex: _currentImageIndex,
                      onSelect: (index) {
                        _galleryPageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut,
                        );
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: ProductInfoHeader(product: effectiveProduct),
                  ),
                ),
                if (effectiveProduct.hasMultipleOptions)
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: ProductVariantSelector(
                        familyProductId: widget.id,
                        selectedProductId: _selectedProductId,
                        onSelect: _selectVariant,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: ProductQuantityRow(
                      quantity: cartQty,
                      price: effectiveProduct.effectivePrice,
                      disableIncrement: isAtPurchaseLimit,
                      onIncrement: () => isAtPurchaseLimit
                          ? AppToast.show(
                              context,
                              'Maximum product order complete',
                            )
                          : _updateCart(effectiveProduct, cartQty + 1),
                      onDecrement: () => _updateCart(
                        effectiveProduct,
                        cartQty > 0 ? cartQty - 1 : 0,
                      ),
                      onAddToCart: () =>
                          _addSelectedVariantToCart(effectiveProduct),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: ProductDeliveryBanner(product: effectiveProduct),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: RepaintBoundary(child: ProductQualityGrid()),
                ),
                SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: ProductStoreRow(productId: effectiveProduct.id),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: ProductTrustBadges(
                      product: effectiveProduct,
                      onBrandTap: () => _navigateToBrand(effectiveProduct),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: ProductDetailTabs(product: effectiveProduct),
                  ),
                ),
                if (effectiveAttributes.isNotEmpty)
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: ProductDetailsSection(
                        attributes: effectiveAttributes,
                        onExpand: () => _logProductDetailsExpand(
                          effectiveProduct,
                          'details',
                        ),
                      ),
                    ),
                  ),
                if (effectiveProduct.hasVendorDetails)
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: ProductVendorSection(
                        vendorName: effectiveProduct.vendorName,
                        vendorAddress: effectiveProduct.vendorAddress,
                        vendorFssai: effectiveProduct.vendorFssai,
                        onExpand: () => _logProductDetailsExpand(
                          effectiveProduct,
                          'vendor',
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: SimilarWrapper(
                      productId: effectiveProduct.id,
                      enabled: _hasReachedRecommendations,
                      onProductTap: (targetProduct) => _handleSimilarTap(
                        effectiveProduct,
                        targetProduct,
                      ),
                      onSeeAll: () => _openSimilarProducts(effectiveProduct),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: RecentlyViewedWrapper(
                      productId: effectiveProduct.id,
                      enabled: _hasReachedRecommendations,
                      onProductTap: (targetProduct) =>
                          _openProduct(targetProduct),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: PairWithWrapper(
                      productId: effectiveProduct.id,
                      enabled: _hasReachedRecommendations,
                      onProductTap: (targetProduct) => _handlePairWithTap(
                        effectiveProduct,
                        targetProduct,
                      ),
                      onSeeAll: _openRecommendedProducts,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: SizedBox(height: 80),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: ProductBottomBar(
              product: effectiveProduct,
              quantity: cartQty,
              onAddToCart: () => _addSelectedVariantToCart(effectiveProduct),
              onViewCart: () => context.push(RouteNames.cart),
              onQuantityChange: (qty) => _updateCart(effectiveProduct, qty),
              disableIncrement: isAtPurchaseLimit,
            ),
          ),
        );
      },
    );
  }

  void _navigateToSearch() {
    context.push(RouteNames.search);
  }

  /// A shared product link (e.g. bakaloo.in/products/:slug, opened via App
  /// Links) cold-starts the app directly onto this screen with nothing
  /// else on the navigation stack. `Navigator.pop` on an empty stack left
  /// the user staring at a black screen instead of leaving the app or
  /// going anywhere useful — check canPop first and fall back to home.
  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      context.go(RouteNames.home);
    }
  }

  void _openProduct(ProductEntity product) {
    if (product.id == _selectedProductId) {
      return;
    }
    context.push('/product/${product.id}');
  }

  void _navigateToBrand(ProductEntity product) {
    final title = product.brandDisplay.trim().isNotEmpty
        ? product.brandDisplay.trim()
        : 'Products';
    unawaited(
      ref.read(analyticsServiceProvider).logProductBrandTap(
            product.id,
            title,
          ),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductListScreen(
          categoryId: product.categoryId,
          title: title,
        ),
      ),
    );
  }

  void _openRecommendedProducts() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ProductListScreen(title: 'Recommended products'),
      ),
    );
  }

  void _openSimilarProducts(ProductEntity product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductListScreen(
          categoryId: product.categoryId,
          title: 'Similar Products',
        ),
      ),
    );
  }

  Future<void> _shareProduct(ProductEntity product) async {
    // Must match bakaloo-customer-web's actual route shape
    // (src/app/(shop)/products/[slug]/page.tsx) — plural "products", by
    // slug, not the app's own internal /product/:id route — or the link
    // 404s for anyone without the app installed (e.g. a WhatsApp preview
    // or a desktop click).
    final shareUri = Uri.tryParse(ApiConstants.webBaseUrl)?.replace(
      path: '/products/${product.slug}',
      queryParameters: null,
    );
    final message = shareUri == null
        ? 'Check out ${product.name} on FreshCuts.'
        : 'Check out ${product.name} on FreshCuts.\n$shareUri';
    await Share.share(message);
  }

  void _handlePairWithTap(
    ProductEntity currentProduct,
    ProductEntity targetProduct,
  ) {
    unawaited(
      ref.read(analyticsServiceProvider).logProductPairWithTap(
            currentProduct.id,
            targetProduct.id,
          ),
    );
    _openProduct(targetProduct);
  }

  void _handleSimilarTap(
    ProductEntity currentProduct,
    ProductEntity targetProduct,
  ) {
    unawaited(
      ref.read(analyticsServiceProvider).logProductSimilarTap(
            currentProduct.id,
            targetProduct.id,
          ),
    );
    _openProduct(targetProduct);
  }

  void _logProductImageSwipe(ProductEntity product, int imageIndex) {
    unawaited(
      ref.read(analyticsServiceProvider).logProductImageSwipe(
            product.id,
            imageIndex,
          ),
    );
  }

  void _logProductHighlightsView(ProductEntity product) {
    unawaited(
      ref.read(analyticsServiceProvider).logProductHighlightsView(product.id),
    );
  }

  void _logProductDetailsExpand(
    ProductEntity product,
    String sectionName,
  ) {
    unawaited(
      ref.read(analyticsServiceProvider).logProductDetailsExpand(
            product.id,
            sectionName,
          ),
    );
  }

  Future<void> _toggleWishlist(ProductEntity product) async {
    final authGate = ref.read(authGateControllerProvider);
    final allowed = await authGate.protectWishlist(context, product);
    if (!allowed || !mounted) {
      return;
    }

    final isInWishlist = ref.read(wishlistIdsProvider).contains(product.id);
    unawaited(
      ref.read(analyticsServiceProvider).logWishlistToggle(
            product.id,
            isInWishlist ? 'remove' : 'add',
          ),
    );
    final result =
        await ref.read(wishlistProvider.notifier).toggleWishlist(product);
    if (!mounted || result.isSuccess) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(result.failure!.message)),
      );
  }

  // Used by this screen's own bottom bar. The "Select Unit" chip row
  // (when present) already lets the customer choose the exact variant
  // in place, so this skips straight to adding whichever variant is
  // currently displayed instead of popping the options sheet again on top
  // of it. The recommendation rails (Pair With / Similar / Recently
  // Viewed) no longer route through here — their shared `ProductCard` adds
  // to cart (and opens the options sheet for multi-option products) itself.
  Future<void> _addSelectedVariantToCart(ProductEntity product) async {
    if (!product.inStock) {
      showCartSnackBar(context, 'This product is currently unavailable.');
      return;
    }

    await _addProductToCart(product);
  }

  Future<void> _addProductToCart(ProductEntity product) async {
    // Re-checked fresh on every tap (ref.read, not a watched value) so a
    // stale cache can never let a mutation through — block before it ever
    // reaches the network.
    final purchaseLimitStatus =
        ref.read(purchaseLimitStatusProvider(product.id));
    if (purchaseLimitStatus?.isAtLimit ?? false) {
      AppToast.show(context, 'Maximum product order complete');
      return;
    }

    final authGate = ref.read(authGateControllerProvider);
    final allowed = await authGate.protectAddToCart(context, product);
    if (!allowed || !mounted) {
      return;
    }

    unawaited(
      ref.read(analyticsServiceProvider).logAddToCart(
            product.id,
            1,
            product.effectivePrice,
          ),
    );
    final result = await ref.read(cartProvider.notifier).addItem(
          product.id,
          1,
          product: product,
          shopProductId: product.shopProductId,
        );
    if (!mounted || result.isSuccess) {
      return;
    }

    showCartSnackBar(context, result.failure!.message);
  }

  Future<void> _updateCart(ProductEntity product, int qty) async {
    final currentQty = ref.read(cartItemQuantityProvider(product.id));
    if (qty > currentQty) {
      // This is an increment attempt (ProductBottomBar's onQuantityChange
      // is a single callback shared by both +/-, so the direction is
      // inferred from whether qty went up). Re-checked fresh on every tap
      // (ref.read, not a watched value) so a stale cache can never let a
      // mutation through — block before it ever reaches the network.
      final purchaseLimitStatus =
          ref.read(purchaseLimitStatusProvider(product.id));
      if (purchaseLimitStatus?.isAtLimit ?? false) {
        AppToast.show(context, 'Maximum product order complete');
        return;
      }
    }

    final result = qty <= 0
        ? await ref.read(cartProvider.notifier).removeItem(
              product.id,
              shopProductId: product.shopProductId,
            )
        : await ref.read(cartProvider.notifier).updateItem(
              product.id,
              qty,
              shopProductId: product.shopProductId,
            );

    if (!mounted || result.isSuccess) {
      return;
    }
    showCartSnackBar(context, result.failure!.message);
  }
}
