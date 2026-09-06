import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/categories/domain/entities/category_entity.dart';
import 'package:bakaloo_flutter_app/features/categories/presentation/providers/category_provider.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/product_list_provider.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/presentation/providers/purchase_limits_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/widgets/empty_state.dart';
import 'package:bakaloo_flutter_app/shared/widgets/error_state.dart';
import 'package:bakaloo_flutter_app/shared/widgets/product_card.dart';
import 'package:bakaloo_flutter_app/shared/widgets/skeleton_loader.dart';

/// Categories accent (premium violet, consistent with Orders/Product screens).
const Color _accent = AppColors.orderViolet;
const Color _accentSurface = AppColors.orderVioletSurface;

/// The product grid is 2 columns inside the pane to the right of the
/// 92.w category rail, with 14.w side padding and a 12.w gap between columns.
double _gridColumnWidth(double paneWidth) {
  final double gridWidth = paneWidth - 14.w * 2;
  return (gridWidth - 12.w) / 2;
}

/// Mirrors ProductCard's grid-style layout (image = 84% of card width, plus
/// a roughly fixed footer for the unit/ADD row, price, name, and rating) so
/// the grid row stays tall enough for the real column width instead of a
/// constant tuned for phone-narrow columns. A fixed `mainAxisExtent` can't
/// work across both phone and tablet: iPad's 2-column grid is far wider per
/// column, so the width-proportional image alone was blowing past the old
/// fixed 256.h row height.
double _gridRowExtent(double columnWidth) => columnWidth * 0.84 + 154.h;

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({this.initialCategoryId, super.key});

  /// Category tapped from [CategoryLandingScreen]'s grid — pre-selects this
  /// category (or its parent, with this one as the active child feed) on
  /// first load instead of always defaulting to the first root category.
  final String? initialCategoryId;

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  String? _selectedParentId;
  String? _selectedFeedId;
  bool _hasSeededInitial = false;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryCollectionProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const _CategoriesHeader(),
            Expanded(
              child: categoriesAsync.when(
                loading: _buildLoading,
                error: (error, stackTrace) => ErrorState(
                  message: 'Categories could not be loaded.',
                  onRetry: () => ref.invalidate(categoryCollectionProvider),
                ),
                data: _buildData,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildData(List<CategoryEntity> categories) {
    if (categories.isEmpty) {
      return const EmptyState(
        title: 'No categories available',
        message: 'Categories will show up here once the API returns them.',
      );
    }

    final sorted = <CategoryEntity>[
      // BUNDLE categories are promo-only groupings surfaced via a banner
      // deep-link — never shown in normal category browsing.
      ...categories
          .where((category) => category.isActive && !category.isBundle),
    ]..sort((a, b) {
        final sortOrder = a.sortOrder.compareTo(b.sortOrder);
        if (sortOrder != 0) {
          return sortOrder;
        }
        return a.name.compareTo(b.name);
      });

    final parents =
        sorted.where((category) => category.isParent).toList(growable: false);
    final rootCategories = parents.isNotEmpty ? parents : sorted;

    if (!_hasSeededInitial && widget.initialCategoryId != null) {
      _hasSeededInitial = true;
      CategoryEntity? match;
      for (final category in sorted) {
        if (category.id == widget.initialCategoryId) {
          match = category;
          break;
        }
      }
      if (match != null) {
        if (match.isParent) {
          _selectedParentId = match.id;
          _selectedFeedId = match.id;
        } else if (match.parentId != null) {
          _selectedParentId = match.parentId;
          _selectedFeedId = match.id;
        }
      }
    }

    _selectedParentId ??= rootCategories.first.id;

    final selectedParent = rootCategories.firstWhere(
      (category) => category.id == _selectedParentId,
      orElse: () => rootCategories.first,
    );
    final childCategories = sorted
        .where((category) => category.parentId == selectedParent.id)
        .toList(growable: false);

    final validFeedIds = <String>{
      selectedParent.id,
      ...childCategories.map((category) => category.id),
    };
    final selectedFeedId = validFeedIds.contains(_selectedFeedId)
        ? _selectedFeedId!
        : selectedParent.id;
    _selectedFeedId = selectedFeedId;

    final highlightedCategory = selectedFeedId == selectedParent.id
        ? selectedParent
        : childCategories.firstWhere(
            (category) => category.id == selectedFeedId,
            orElse: () => selectedParent,
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _CategoryRail(
          categories: rootCategories,
          selectedCategoryId: selectedParent.id,
          onSelect: (category) {
            setState(() {
              _selectedParentId = category.id;
              _selectedFeedId = category.id;
            });
          },
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _CategoryProductPane(
              key: ValueKey<String>('${selectedParent.id}-$selectedFeedId'),
              selectedParent: selectedParent,
              highlightedCategory: highlightedCategory,
              childCategories: childCategories,
              selectedFeedId: selectedFeedId,
              onSelectChild: (categoryId) {
                setState(() {
                  _selectedFeedId = categoryId;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 92.w,
          color: AppColors.bgPrimary,
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Column(
            children: <Widget>[
              for (var i = 0; i < 8; i++) ...<Widget>[
                const SkeletonLoader(height: 64, radius: 16),
                Gap(12.h),
              ],
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 24.h),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double columnWidth = (constraints.maxWidth - 12.w) / 2;
                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 6,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12.w,
                    mainAxisSpacing: 14.h,
                    mainAxisExtent: _gridRowExtent(columnWidth),
                  ),
                  itemBuilder: (_, __) =>
                      const SkeletonLoader(height: 220, radius: 16),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoriesHeader extends ConsumerWidget {
  const _CategoriesHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartCountProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // This screen is only ever reached by pushing on top of
          // CategoryLandingScreen (never the bottom-nav tab's own root
          // anymore), so it always needs its own explicit way back —
          // relying solely on the hardware/gesture back button here isn't
          // reliable across the shell's nested branch navigators.
          _HeaderIconButton(
            icon: PhosphorIcons.arrowLeftBold,
            semanticLabel: 'Back',
            onTap: () => context.canPop()
                ? context.pop()
                : context.go(RouteNames.categories),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Categories', style: AppTextStyles.h1),
                SizedBox(height: 2.h),
                Text(
                  'Shop from the widest range',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          _HeaderIconButton(
            icon: PhosphorIcons.magnifyingGlassBold,
            semanticLabel: 'Search',
            onTap: () => context.push(RouteNames.search),
          ),
          SizedBox(width: 10.w),
          _HeaderIconButton(
            icon: PhosphorIcons.shoppingCartSimpleBold,
            semanticLabel: 'Cart',
            badgeCount: cartCount,
            onTap: () => context.push(RouteNames.cart),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.badgeCount = 0,
  });

  final PhosphorIconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46.w,
          height: 46.w,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Center(
                  child: PhosphorIcon(icon, size: 19.sp, color: _accent),
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  right: 2.w,
                  top: 2.h,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                    constraints: BoxConstraints(minWidth: 16.w),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(100.r),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelect,
  });

  final List<CategoryEntity> categories;
  final String selectedCategoryId;
  final ValueChanged<CategoryEntity> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92.w,
      decoration: const BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border(
          right: BorderSide(color: AppColors.divider),
        ),
      ),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return _CategoryRailItem(
            category: category,
            isSelected: category.id == selectedCategoryId,
            onTap: () => onSelect(category),
          );
        },
      ),
    );
  }
}

class _CategoryRailItem extends StatelessWidget {
  const _CategoryRailItem({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final CategoryEntity category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      child: Material(
        color: isSelected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: onTap,
          child: Stack(
            children: <Widget>[
              // Active indicator bar on the left edge.
              if (isSelected)
                Positioned(
                  left: 0,
                  top: 14.h,
                  bottom: 14.h,
                  child: Container(
                    width: 3.w,
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(100.r),
                    ),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.orderVioletBorder
                        : Colors.transparent,
                  ),
                ),
                padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 4.w),
                child: Column(
                  children: <Widget>[
                    _CategoryThumb(
                      imageUrl: category.imageUrl,
                      name: category.name,
                      isSelected: isSelected,
                    ),
                    Gap(6.h),
                    Text(
                      category.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5.sp,
                        color: isSelected ? _accent : AppColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Category thumbnail with a premium fallback (tinted monogram) when the API
/// returns no image — which is currently the common case.
class _CategoryThumb extends StatelessWidget {
  const _CategoryThumb({
    required this.imageUrl,
    required this.name,
    required this.isSelected,
  });

  final String? imageUrl;
  final String name;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final size = 46.w;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isSelected ? _accentSurface : AppColors.bgInput,
        borderRadius: BorderRadius.circular(14.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              memCacheWidth: 200,
              memCacheHeight: 200,
              filterQuality: FilterQuality.high,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  const SkeletonLoader(height: 46, radius: 14),
              errorWidget: (context, url, error) =>
                  _Monogram(name: name, isSelected: isSelected),
            )
          : _Monogram(name: name, isSelected: isSelected),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.name, required this.isSelected});

  final String name;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: isSelected ? _accent : AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _CategoryProductPane extends ConsumerStatefulWidget {
  const _CategoryProductPane({
    required this.selectedParent,
    required this.highlightedCategory,
    required this.childCategories,
    required this.selectedFeedId,
    required this.onSelectChild,
    super.key,
  });

  final CategoryEntity selectedParent;
  final CategoryEntity highlightedCategory;
  final List<CategoryEntity> childCategories;
  final String selectedFeedId;
  final ValueChanged<String> onSelectChild;

  @override
  ConsumerState<_CategoryProductPane> createState() =>
      _CategoryProductPaneState();
}

class _CategoryProductPaneState extends ConsumerState<_CategoryProductPane> {
  late final ScrollController _scrollController;

  // The active feed params — derived from selectedFeedId.
  ProductListParams get _params => ProductListParams(
        categoryId: widget.selectedFeedId,
        title: widget.selectedFeedId == widget.selectedParent.id
            ? widget.selectedParent.name
            : widget.highlightedCategory.name,
      );

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (_scrollController.offset >= max - 300) {
      final viewState = ref.read(productListProvider(_params)).asData?.value;
      if (viewState != null && viewState.hasMore && !viewState.isLoadingMore) {
        ref.read(productListProvider(_params).notifier).loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productListAsync = ref.watch(productListProvider(_params));

    final feedCategoryName = widget.selectedFeedId == widget.selectedParent.id
        ? widget.selectedParent.name
        : widget.highlightedCategory.name;

    // Show the category's true total, not how many items have loaded
    // into the list so far — the first page lands at the page size
    // (e.g. 20), so the header used to read "20 products" until the
    // user scrolled far enough to fetch the rest and it happened to
    // catch up to the real total.
    //
    // BUT the category's stored product_count is a simple "is this
    // product active" tally with no awareness of which shops actually
    // serve this customer's delivery location — the product-list query
    // applies that shop-allocation scoping, the count query doesn't. A
    // category can legitimately report more products than this customer
    // can actually see (e.g. "5 products" while only 3 are sold by a shop
    // that delivers here). Once the list has fully loaded (no more pages
    // left to fetch), loadedCount is the true, customer-accurate figure
    // and should win over the stale metadata total; before that, still
    // fall back to totalCount so the header doesn't flash a low
    // first-page number while more pages are on the way.
    final viewState = productListAsync.asData?.value;
    final loadedCount = viewState?.items.length ?? 0;
    final totalCount = widget.highlightedCategory.productCount;
    final fullyLoaded =
        viewState != null && !viewState.hasMore && !viewState.isLoadingMore;
    final countLabel = fullyLoaded
        ? '$loadedCount products'
        : (totalCount > 0 ? '$totalCount products' : '$loadedCount products');

    return CustomScrollView(
      key: widget.key,
      controller: _scrollController,
      slivers: <Widget>[
        if (widget.childCategories.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 0),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                height: 38.h,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    _CategoryFilterChip(
                      label: 'All',
                      selected:
                          widget.selectedFeedId == widget.selectedParent.id,
                      onTap: () =>
                          widget.onSelectChild(widget.selectedParent.id),
                    ),
                    ...widget.childCategories.map(
                      (category) => Padding(
                        padding: EdgeInsets.only(left: 8.w),
                        child: _CategoryFilterChip(
                          label: category.name,
                          selected: widget.selectedFeedId == category.id,
                          onTap: () => widget.onSelectChild(category.id),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 10.h),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        feedCategoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h3.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        countLabel,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        productListAsync.when(
          loading: _buildLoadingSliver,
          error: (error, stackTrace) => SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorState(
              message: error.toString().replaceFirst('Bad state: ', ''),
              onRetry: () =>
                  ref.read(productListProvider(_params).notifier).refresh(),
            ),
          ),
          data: (viewState) {
            if (viewState.items.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  title: 'No products in this aisle yet',
                  message:
                      'Try a different category or check back once more inventory is added.',
                ),
              );
            }

            // Piggybacks on the category product-list fetch that's already
            // happening — no extra per-card network call. Cheap no-op once
            // already known.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(purchaseLimitsNotifierProvider.notifier).ensureLoaded(
                    viewState.items.map((product) => product.id).toList(),
                  );
            });

            return SliverLayoutBuilder(
              builder: (context, sliverConstraints) {
                final double columnWidth =
                    _gridColumnWidth(sliverConstraints.crossAxisExtent);

                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 4.h),
                  sliver: SliverGrid.builder(
                    itemCount: viewState.items.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12.w,
                      mainAxisSpacing: 14.h,
                      mainAxisExtent: _gridRowExtent(columnWidth),
                    ),
                    itemBuilder: (context, index) {
                      final product = viewState.items[index];
                      return TweenAnimationBuilder<double>(
                        duration: Duration(
                          milliseconds: 220 + ((index % 6) * 30),
                        ),
                        curve: Curves.easeOutCubic,
                        tween: Tween<double>(begin: 0, end: 1),
                        child: ProductCard(
                          product: product,
                          // ProductCard re-applies `.w` internally, so pass
                          // the real column width pre-divided by the scale
                          // factor (same convention as _threeColumnCardWidth
                          // in home_screen.dart) — otherwise it gets scaled
                          // twice and the card balloons past its own column.
                          width: columnWidth / ScreenUtil().scaleWidth,
                          style: ProductCardStyle.grid,
                          useCompactAddButton: true,
                          showImageBorder: true,
                          accentColor: _accent,
                          onTap: () => context.push('/product/${product.id}'),
                          onOptionsTap: product.hasMultipleOptions
                              ? () => showProductOptionsSheet(context, product)
                              : null,
                        ),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, (1 - value) * 16),
                              child: child,
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
        // Inline footer: spinner while loading more, or "seen all" when done.
        SliverToBoxAdapter(
          child: Builder(
            builder: (context) {
              final viewState = productListAsync.asData?.value;
              if (viewState == null) return const SizedBox.shrink();
              if (viewState.isLoadingMore) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 18.h),
                  child: Center(
                    child: SizedBox(
                      width: 22.w,
                      height: 22.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(_accent),
                      ),
                    ),
                  ),
                );
              }
              if (!viewState.hasMore && viewState.items.length > 20) {
                return Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 28.h),
                  child: Center(
                    child: Text(
                      "You've seen all ${viewState.items.length} products",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                );
              }
              return SizedBox(height: 24.h);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSliver() {
    return SliverLayoutBuilder(
      builder: (context, sliverConstraints) {
        final double columnWidth =
            _gridColumnWidth(sliverConstraints.crossAxisExtent);

        return SliverPadding(
          padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 20.h),
          sliver: SliverGrid.builder(
            itemCount: 6,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 14.h,
              mainAxisExtent: _gridRowExtent(columnWidth),
            ),
            itemBuilder: (_, __) => const SkeletonLoader(
              height: 220,
              radius: 16,
            ),
          ),
        );
      },
    );
  }
}

// ── Category filter chips ──────────────────────────────────────────────────

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _accent : Colors.white,
      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            border: Border.all(
              color: selected ? _accent : AppColors.borderLight,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
