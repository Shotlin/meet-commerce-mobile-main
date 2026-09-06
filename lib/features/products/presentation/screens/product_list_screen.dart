import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/providers/product_list_provider.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/presentation/providers/purchase_limits_provider.dart';
import 'package:bakaloo_flutter_app/shared/widgets/empty_state.dart';
import 'package:bakaloo_flutter_app/shared/widgets/error_state.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:bakaloo_flutter_app/shared/widgets/product_card.dart';
import 'package:bakaloo_flutter_app/shared/widgets/skeleton_loader.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({
    this.categoryId,
    this.title = 'Products',
    super.key,
  });

  final String? categoryId;
  final String title;

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  late final ScrollController _scrollController;

  ProductListParams get _params => ProductListParams(
        categoryId: widget.categoryId,
        title: widget.title,
      );

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
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
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    // Trigger 300px before the end
    if (current >= maxScroll - 300) {
      final viewState = ref.read(productListProvider(_params)).asData?.value;
      if (viewState != null && viewState.hasMore && !viewState.isLoadingMore) {
        ref.read(productListProvider(_params).notifier).loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productListAsync = ref.watch(productListProvider(_params));

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: Text(widget.title)),
      body: productListAsync.when(
        loading: _buildLoading,
        error: (error, stackTrace) => ErrorState(
          message: error.toString().replaceFirst('Bad state: ', ''),
          onRetry: () {
            ref.read(productListProvider(_params).notifier).refresh();
          },
        ),
        data: (viewState) {
          if (viewState.items.isEmpty) {
            return const EmptyState(
              title: 'No products yet',
              message:
                  'Products will appear here when inventory is available.',
            );
          }

          // Piggybacks on the product-list fetch that's already happening —
          // no extra per-card network call. Cheap no-op once already known.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(purchaseLimitsNotifierProvider.notifier).ensureLoaded(
                  viewState.items.map((product) => product.id).toList(),
                );
          });

          return RefreshIndicator(
            onRefresh: () async {
              ref.read(productListProvider(_params).notifier).refresh();
              await ref.read(productListProvider(_params).future);
            },
            color: AppColors.primaryGreen,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: <Widget>[
                if (viewState.isStale)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: AppColors.accentYellowLight,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: Text(
                        'Showing cached products. Reconnect to see the latest inventory.',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.all(16.w),
                  sliver: SliverGrid.builder(
                    itemCount: viewState.items.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12.w,
                      mainAxisSpacing: 12.h,
                      mainAxisExtent: 268.h,
                    ),
                    itemBuilder: (context, index) {
                      final product = viewState.items[index];
                      final isNew = viewState.newItemCount > 0 &&
                          index >=
                              viewState.items.length -
                                  viewState.newItemCount;
                      final staggerIndex = isNew
                          ? index -
                              (viewState.items.length -
                                  viewState.newItemCount)
                          : 0;

                      return RepaintBoundary(
                        child: _AnimatedCard(
                          key: ValueKey<String>(product.id),
                          animate: isNew,
                          staggerIndex: staggerIndex,
                          child: ProductCard(
                            product: product,
                            style: ProductCardStyle.grid,
                            onTap: () =>
                                context.push('/product/${product.id}'),
                            onOptionsTap: product.hasMultipleOptions
                                ? () => showProductOptionsSheet(
                                      context,
                                      product,
                                    )
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 32.h),
                    child: Column(
                      children: <Widget>[
                        if (viewState.paginationMessage != null)
                          Padding(
                            padding: EdgeInsets.only(bottom: 10.h),
                            child: Text(
                              viewState.paginationMessage!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.warningOrange,
                              ),
                            ),
                          ),
                        if (viewState.isLoadingMore)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            child: SizedBox(
                              width: 24.w,
                              height: 24.w,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primaryGreen,
                                ),
                              ),
                            ),
                          )
                        else if (!viewState.hasMore &&
                            viewState.items.length > 20)
                          Text(
                            "You've seen all ${viewState.items.length} products",
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoading() {
    return GridView.builder(
      padding: EdgeInsets.all(16.w),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        mainAxisExtent: 268.h,
      ),
      itemCount: 8,
      itemBuilder: (_, __) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SkeletonLoader(height: 132, radius: 12),
          Gap(AppDimensions.spacing12),
          SkeletonLoader(height: 14, radius: 8),
          Gap(AppDimensions.spacing8),
          SkeletonLoader(height: 12, width: 80, radius: 8),
        ],
      ),
    );
  }
}

// ── Staggered fade-in + slide-up wrapper ────────────────────────────────────

class _AnimatedCard extends StatefulWidget {
  const _AnimatedCard({
    required this.animate,
    required this.staggerIndex,
    required this.child,
    super.key,
  });

  final bool animate;
  final int staggerIndex;
  final Widget child;

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _opacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0, 0.75, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    if (widget.animate) {
      Future<void>.delayed(
        Duration(milliseconds: widget.staggerIndex * 55),
        () {
          if (mounted) _ctrl.forward();
        },
      );
    } else {
      _ctrl.value = 1;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) return widget.child;
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}


