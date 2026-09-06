import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_gate_controller.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/categories/domain/entities/category_entity.dart';
import 'package:bakaloo_flutter_app/features/categories/presentation/providers/category_provider.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/presentation/providers/purchase_limits_provider.dart';
import 'package:bakaloo_flutter_app/features/search/domain/entities/search_result_entity.dart';
import 'package:bakaloo_flutter_app/features/search/presentation/providers/search_history_provider.dart';
import 'package:bakaloo_flutter_app/features/search/presentation/providers/search_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:bakaloo_flutter_app/shared/widgets/product_card.dart';
import 'package:bakaloo_flutter_app/shared/widgets/quantity_control.dart';
import 'package:bakaloo_flutter_app/shared/widgets/skeleton_loader.dart';

// ─── Sort & Filter enums ─────────────────────────────────────────────────────

enum _SortOption {
  relevance,
  priceLow,
  priceHigh,
  rating,
  popularity,
}

extension _SortOptionLabel on _SortOption {
  String get label {
    switch (this) {
      case _SortOption.relevance:
        return 'Relevance';
      case _SortOption.priceLow:
        return 'Price: Low ↑';
      case _SortOption.priceHigh:
        return 'Price: High ↓';
      case _SortOption.rating:
        return 'Rating';
      case _SortOption.popularity:
        return 'Popularity';
    }
  }

  String get sheetLabel {
    switch (this) {
      case _SortOption.relevance:
        return 'Relevance (default)';
      case _SortOption.priceLow:
        return 'Price: Low to High';
      case _SortOption.priceHigh:
        return 'Price: High to Low';
      case _SortOption.rating:
        return 'Rating';
      case _SortOption.popularity:
        return 'Popularity';
    }
  }
}

enum _PriceRange {
  any,
  under50,
  between50and200,
  above200,
}

extension _PriceRangeLabel on _PriceRange {
  String get label {
    switch (this) {
      case _PriceRange.any:
        return 'Any price';
      case _PriceRange.under50:
        return 'Under ₹50';
      case _PriceRange.between50and200:
        return '₹50 – ₹200';
      case _PriceRange.above200:
        return '₹200+';
    }
  }
}

class _FilterState {
  const _FilterState({
    this.inStockOnly = false,
    this.onSaleOnly = false,
    this.priceRange = _PriceRange.any,
    this.categoryId,
  });

  final bool inStockOnly;
  final bool onSaleOnly;
  final _PriceRange priceRange;
  final String? categoryId;

  bool get isDefault =>
      !inStockOnly &&
      !onSaleOnly &&
      priceRange == _PriceRange.any &&
      categoryId == null;

  int get activeCount {
    int count = 0;
    if (inStockOnly) count++;
    if (onSaleOnly) count++;
    if (priceRange != _PriceRange.any) count++;
    if (categoryId != null) count++;
    return count;
  }

  _FilterState copyWith({
    bool? inStockOnly,
    bool? onSaleOnly,
    _PriceRange? priceRange,
    Object? categoryId = _sentinel,
  }) {
    return _FilterState(
      inStockOnly: inStockOnly ?? this.inStockOnly,
      onSaleOnly: onSaleOnly ?? this.onSaleOnly,
      priceRange: priceRange ?? this.priceRange,
      categoryId: categoryId == _sentinel
          ? this.categoryId
          : categoryId as String?,
    );
  }

  static const Object _sentinel = Object();
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _hints = <String>[
    'Search atta, fruits, milk...',
    'Try onions, tomatoes, rice...',
    'Find chips, juices, bread...',
  ];

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  final PagingController<int, ProductEntity> _pagingController =
      PagingController<int, ProductEntity>(firstPageKey: 1);

  late final AnimationController _overlayController;
  late final Animation<Offset> _slideAnimation;
  Timer? _hintTimer;
  int _hintIndex = 0;
  String _pagedQuery = '';
  bool _isDismissing = false;

  // ─── Sort / filter state ───────────────────────────────────────────────────
  _SortOption _sortOption = _SortOption.relevance;
  _FilterState _filterState = const _FilterState();
  final List<ProductEntity> _allProducts = <ProductEntity>[];
  List<ProductEntity> _displayProducts = <ProductEntity>[];
  int _totalBackendCount = 0;

  @override
  void initState() {
    super.initState();
    _overlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      reverseDuration: const Duration(milliseconds: 250),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _overlayController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _pagingController.addPageRequestListener(_fetchPage);
    _overlayController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });

    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _searchController.text.trim().isNotEmpty) {
        return;
      }

      setState(() {
        _hintIndex = (_hintIndex + 1) % _hints.length;
      });
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    if (_isListening) {
      unawaited(_speech.stop());
    }
    _overlayController.dispose();
    _pagingController.dispose();
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int pageKey) async {
    if (pageKey <= 1 || _pagedQuery.isEmpty) {
      return;
    }

    final requestQuery = _pagedQuery;
    try {
      final result = await ref.read(searchProvider.notifier).searchPage(
            query: requestQuery,
            page: pageKey,
          );

      if (!mounted || requestQuery != _pagedQuery) {
        return;
      }

      final isLastPage = result.pagination.totalPages == 0 ||
          result.pagination.page >= result.pagination.totalPages;

      // Accumulate into _allProducts
      setState(() {
        _allProducts.addAll(result.products);
        _computeDisplayProducts();
      });
      _ensurePurchaseLimitsLoaded(result.products);

      if (isLastPage) {
        _pagingController.appendLastPage(result.products);
      } else {
        _pagingController.appendPage(
          result.products,
          pageKey + 1,
        );
      }
    } catch (error) {
      if (!mounted || requestQuery != _pagedQuery) {
        return;
      }
      _pagingController.error = error;
    }
  }

  Future<void> _dismiss() async {
    if (_isDismissing) {
      return;
    }

    _isDismissing = true;
    await _overlayController.reverse();
    if (!mounted) {
      return;
    }

    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
      return;
    }

    context.go(RouteNames.home);
  }

  void _onQueryChanged(String value) {
    if (mounted) {
      setState(() {});
    }

    if (value.trim().isEmpty) {
      _pagedQuery = '';
      _allProducts.clear();
      _displayProducts = <ProductEntity>[];
      _pagingController.refresh();
    }

    // Reset sort/filter when the query changes
    _sortOption = _SortOption.relevance;
    _filterState = const _FilterState();

    ref.read(searchProvider.notifier).onQueryChanged(value);
  }

  // Re-initializes on every tap rather than once in initState — this is a
  // cheap no-op when the engine's already available, and avoids prompting
  // for the mic/speech permission the moment the search screen opens (most
  // customers never touch voice search at all in a given session).
  Future<void> _toggleVoiceSearch() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    final available = await _speech.initialize(
      onError: (error) {
        if (!mounted) return;
        setState(() => _isListening = false);
        AppToast.show(
          context,
          'Could not start voice search. Please try again.',
          type: ToastType.warning,
        );
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );

    if (!available) {
      if (!mounted) return;
      AppToast.show(
        context,
        '🎙️ Microphone access is needed for voice search.',
        type: ToastType.warning,
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isListening = true);
    _focusNode.requestFocus();
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        _searchController.text = result.recognizedWords;
        _searchController.selection = TextSelection.collapsed(
          offset: _searchController.text.length,
        );
        _onQueryChanged(result.recognizedWords);
        if (result.finalResult) {
          setState(() => _isListening = false);
        }
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  // Piggybacks on the search fetch that's already happening — no extra
  // per-card network call. Cheap no-op for any product already known.
  void _ensurePurchaseLimitsLoaded(List<ProductEntity> products) {
    if (products.isEmpty) {
      return;
    }
    ref.read(purchaseLimitsNotifierProvider.notifier).ensureLoaded(
          products.map((product) => product.id).toList(),
        );
  }

  void _applyFirstPage(SearchResultEntity result) {
    _pagedQuery = _searchController.text.trim();
    final nextPageKey = result.pagination.totalPages > 1 ? 2 : null;
    _pagingController.value = PagingState<int, ProductEntity>(
      itemList: result.products,
      error: null,
      nextPageKey: nextPageKey,
    );
    // Reset accumulated list with first-page products
    _allProducts
      ..clear()
      ..addAll(result.products);
    _totalBackendCount = result.total > 0
        ? result.total
        : (result.pagination.total > 0
            ? result.pagination.total
            : result.products.length);
    _computeDisplayProducts();
  }

  void _computeDisplayProducts() {
    List<ProductEntity> products = List<ProductEntity>.from(_allProducts);

    // Apply filters
    if (_filterState.inStockOnly) {
      products = products.where((p) => p.inStock).toList();
    }
    if (_filterState.onSaleOnly) {
      products = products.where((p) => p.isOnSale).toList();
    }
    if (_filterState.priceRange != _PriceRange.any) {
      products = products.where((p) {
        final price = p.effectivePrice;
        switch (_filterState.priceRange) {
          case _PriceRange.under50:
            return price < 50;
          case _PriceRange.between50and200:
            return price >= 50 && price <= 200;
          case _PriceRange.above200:
            return price > 200;
          case _PriceRange.any:
            return true;
        }
      }).toList();
    }
    if (_filterState.categoryId != null) {
      products =
          products.where((p) => p.categoryId == _filterState.categoryId).toList();
    }

    // Apply sort
    switch (_sortOption) {
      case _SortOption.relevance:
        break; // keep backend order
      case _SortOption.priceLow:
        products.sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
      case _SortOption.priceHigh:
        products.sort((a, b) => b.effectivePrice.compareTo(a.effectivePrice));
      case _SortOption.rating:
        products.sort((a, b) => b.avgRating.compareTo(a.avgRating));
      case _SortOption.popularity:
        products.sort((a, b) => b.totalSold.compareTo(a.totalSold));
    }

    _displayProducts = products;
  }

  Future<void> _showSortSheet(BuildContext context) async {
    _SortOption tempSort = _sortOption;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(0, 8.h, 0, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: AppColors.bgSection,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusFull),
                      ),
                    ),
                  ),
                  Gap(14.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text('Sort by', style: AppTextStyles.h3),
                        ),
                        GestureDetector(
                          onTap: () {
                            setModalState(() {
                              tempSort = _SortOption.relevance;
                            });
                          },
                          child: Text(
                            'Reset',
                            style: AppTextStyles.buttonSmall.copyWith(
                              color: AppColors.orderViolet,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Gap(8.h),
                  const Divider(height: 1, color: AppColors.divider),
                  ..._SortOption.values.map((option) {
                    final isSelected = tempSort == option;
                    return InkWell(
                      onTap: () => setModalState(() => tempSort = option),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 20.w, vertical: 14.h),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                option.sheetLabel,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: isSelected
                                      ? AppColors.orderViolet
                                      : AppColors.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (isSelected)
                              PhosphorIcon(
                                PhosphorIcons.checkBold,
                                size: 18.sp,
                                color: AppColors.orderViolet,
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const Divider(height: 1, color: AppColors.divider),
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          setState(() {
                            _sortOption = tempSort;
                            _computeDisplayProducts();
                          });
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.orderViolet,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusFull),
                          ),
                        ),
                        child: Text(
                          'Apply',
                          style: AppTextStyles.buttonMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: MediaQuery.of(ctx).padding.bottom,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showFilterSheet(BuildContext ctx) async {
    _FilterState tempFilter = _filterState;
    final categories =
        ref.read(categoryCollectionProvider).asData?.value ?? <CategoryEntity>[];

    await showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.92,
              builder: (_, scrollController) {
                return Column(
                  children: <Widget>[
                    // Handle + header
                    Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 0),
                      child: Column(
                        children: <Widget>[
                          Center(
                            child: Container(
                              width: 40.w,
                              height: 4.h,
                              decoration: BoxDecoration(
                                color: AppColors.bgSection,
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusFull),
                              ),
                            ),
                          ),
                          Gap(14.h),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  'Filters',
                                  style: AppTextStyles.h3,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setModalState(() {
                                  tempFilter = const _FilterState();
                                }),
                                child: Text(
                                  'Reset',
                                  style: AppTextStyles.buttonSmall.copyWith(
                                    color: AppColors.orderViolet,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Gap(12.h),
                          const Divider(height: 1, color: AppColors.divider),
                        ],
                      ),
                    ),
                    // Scrollable body
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
                        children: <Widget>[
                          // In Stock
                          _FilterSwitchRow(
                            label: 'In Stock only',
                            value: tempFilter.inStockOnly,
                            onChanged: (v) =>
                                setModalState(() => tempFilter =
                                    tempFilter.copyWith(inStockOnly: v)),
                          ),
                          Gap(4.h),
                          // On Sale
                          _FilterSwitchRow(
                            label: 'On Sale only',
                            value: tempFilter.onSaleOnly,
                            onChanged: (v) =>
                                setModalState(() => tempFilter =
                                    tempFilter.copyWith(onSaleOnly: v)),
                          ),
                          Gap(16.h),
                          const Divider(height: 1, color: AppColors.divider),
                          Gap(14.h),
                          // Price range
                          Text(
                            'Price range',
                            style: AppTextStyles.labelLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Gap(10.h),
                          Wrap(
                            spacing: 8.w,
                            runSpacing: 8.h,
                            children: _PriceRange.values.map((range) {
                              final isSelected =
                                  tempFilter.priceRange == range;
                              return GestureDetector(
                                onTap: () => setModalState(() => tempFilter =
                                    tempFilter.copyWith(priceRange: range)),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 14.w, vertical: 8.h),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.orderVioletSurface
                                        : AppColors.bgSection,
                                    borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusFull),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.orderVioletBorder
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Text(
                                    range.label,
                                    style: AppTextStyles.chip.copyWith(
                                      color: isSelected
                                          ? AppColors.orderViolet
                                          : AppColors.textSecondary,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          if (categories.isNotEmpty) ...<Widget>[
                            Gap(16.h),
                            const Divider(height: 1, color: AppColors.divider),
                            Gap(14.h),
                            Text(
                              'Category',
                              style: AppTextStyles.labelLarge.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Gap(10.h),
                            Wrap(
                              spacing: 8.w,
                              runSpacing: 8.h,
                              children: categories.map((cat) {
                                final isSelected =
                                    tempFilter.categoryId == cat.id;
                                return GestureDetector(
                                  onTap: () => setModalState(
                                    () => tempFilter = tempFilter.copyWith(
                                      categoryId:
                                          isSelected ? null : cat.id,
                                    ),
                                  ),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 14.w, vertical: 8.h),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.orderVioletSurface
                                          : AppColors.bgSection,
                                      borderRadius: BorderRadius.circular(
                                          AppDimensions.radiusFull),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.orderVioletBorder
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: Text(
                                      cat.name,
                                      style: AppTextStyles.chip.copyWith(
                                        color: isSelected
                                            ? AppColors.orderViolet
                                            : AppColors.textSecondary,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                          Gap(24.h),
                        ],
                      ),
                    ),
                    // Apply button
                    const Divider(height: 1, color: AppColors.divider),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          20.w,
                          12.h,
                          20.w,
                          12.h + MediaQuery.of(sheetCtx).padding.bottom),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(sheetCtx).pop();
                            setState(() {
                              _filterState = tempFilter;
                              _computeDisplayProducts();
                            });
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.orderViolet,
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusFull),
                            ),
                          ),
                          child: Text(
                            'Apply',
                            style: AppTextStyles.buttonMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _fillQuery(String query) {
    _searchController
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);
    _focusNode.requestFocus();
    _onQueryChanged(query);
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final history = ref.watch(searchHistoryProvider);
    final categoriesAsync = ref.watch(categoryCollectionProvider);
    final hasQuery = _searchController.text.trim().isNotEmpty;
    ref.listen<AsyncValue<SearchResultEntity>>(searchProvider,
        (previous, next) {
      next.whenOrNull(
        data: (result) {
          ref.read(searchHistoryProvider.notifier).refresh();

          if (_searchController.text.trim().isEmpty) {
            _pagedQuery = '';
            _allProducts.clear();
            _displayProducts = <ProductEntity>[];
            _pagingController.refresh();
            return;
          }

          if (result.products.isEmpty) {
            _pagedQuery = _searchController.text.trim();
            _allProducts.clear();
            _displayProducts = <ProductEntity>[];
            _pagingController.value = const PagingState<int, ProductEntity>(
              itemList: <ProductEntity>[],
              error: null,
              nextPageKey: null,
            );
            return;
          }

          _applyFirstPage(result);
          _ensurePurchaseLimitsLoaded(result.products);
        },
        error: (error, stackTrace) {
          _pagingController.error = error;
        },
      );
    });

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_dismiss());
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: SafeArea(
          child: SlideTransition(
            position: _slideAnimation,
            child: Material(
              color: AppColors.bgPrimary,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                    child: Row(
                      children: <Widget>[
                        _CircleIconButton(
                          icon: PhosphorIcons.arrowLeftBold,
                          semanticLabel: 'Back',
                          onTap: _dismiss,
                        ),
                        Gap(12.w),
                        Expanded(
                          child: _SearchInput(
                            controller: _searchController,
                            focusNode: _focusNode,
                            hint: _hints[_hintIndex],
                            onChanged: _onQueryChanged,
                          ),
                        ),
                        Gap(12.w),
                        _CircleIconButton(
                          icon: _isListening
                              ? PhosphorIcons.stopBold
                              : (_searchController.text.trim().isEmpty
                                  ? PhosphorIcons.microphoneBold
                                  : PhosphorIcons.xBold),
                          iconColor: _isListening
                              ? AppColors.errorRed
                              : (_searchController.text.trim().isEmpty
                                  ? AppColors.orderViolet
                                  : AppColors.textSecondary),
                          semanticLabel: _isListening
                              ? 'Stop voice search'
                              : (_searchController.text.trim().isEmpty
                                  ? 'Voice search'
                                  : 'Clear search'),
                          onTap: _isListening ||
                                  _searchController.text.trim().isEmpty
                              ? _toggleVoiceSearch
                              : () {
                                  _searchController.clear();
                                  _focusNode.requestFocus();
                                  _onQueryChanged('');
                                },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.08),
                            end: Offset.zero,
                          ).animate(animation),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: !hasQuery
                          ? _EmptySearchState(
                              key: const ValueKey<String>('empty'),
                              history: history,
                              categories: categoriesAsync.asData?.value ??
                                  const <CategoryEntity>[],
                              onChipTap: _fillQuery,
                              onCategoryTap: (category) {
                                context.push(
                                  '/categories/${category.id}/products',
                                );
                              },
                              onViewAllProducts: () {
                                context.push(RouteNames.categories);
                              },
                              onRemoveHistory: (query) {
                                ref
                                    .read(searchHistoryProvider.notifier)
                                    .removeQuery(query);
                              },
                              onClearHistory: () {
                                ref
                                    .read(searchHistoryProvider.notifier)
                                    .clearAll();
                              },
                            )
                          : searchState.when(
                              loading: () => const _DebouncingState(
                                key: ValueKey<String>('loading'),
                              ),
                              error: (error, stackTrace) => _SearchErrorState(
                                key: const ValueKey<String>('error'),
                                message: error
                                    .toString()
                                    .replaceFirst('Bad state: ', ''),
                                onRetry: () {
                                  ref.read(searchProvider.notifier).retry();
                                },
                              ),
                              data: (result) {
                                if (result.products.isEmpty) {
                                  return _NoResultsState(
                                    key: const ValueKey<String>('no-results'),
                                    query: _searchController.text.trim(),
                                    suggestions: result.suggestions,
                                  );
                                }

                                return _SearchResultsState(
                                  key: const ValueKey<String>('results'),
                                  pagingController: _pagingController,
                                  displayProducts: _displayProducts,
                                  allProductsCount: _allProducts.length,
                                  totalBackendCount: _totalBackendCount,
                                  sortOption: _sortOption,
                                  filterState: _filterState,
                                  onSortTap: () => _showSortSheet(context),
                                  onFilterTap: () =>
                                      _showFilterSheet(context),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: AppColors.bgCard,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.borderLight),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44.w,
            height: 44.w,
            child: Center(
              child: PhosphorIcon(
                icon,
                size: 20.sp,
                color: iconColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50.h,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Stack(
        children: <Widget>[
          TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            cursorColor: AppColors.orderViolet,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(left: 16.w, right: 10.w),
                child: PhosphorIcon(
                  PhosphorIcons.magnifyingGlassBold,
                  size: 20.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              contentPadding: EdgeInsets.symmetric(vertical: 15.h),
            ),
          ),
          if (controller.text.isEmpty)
            Positioned(
              left: 46.w,
              right: 16.w,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      hint,
                      key: ValueKey<String>(hint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ).animate().fadeIn(duration: 250.ms),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryCardPalette {
  const _CategoryCardPalette({
    required this.background,
    required this.iconBackground,
    required this.iconColor,
    required this.icon,
  });

  final Color background;
  final Color iconBackground;
  final Color iconColor;
  final IconData icon;
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({
    required this.history,
    required this.categories,
    required this.onChipTap,
    required this.onCategoryTap,
    required this.onViewAllProducts,
    required this.onRemoveHistory,
    required this.onClearHistory,
    super.key,
  });

  final List<String> history;
  final List<CategoryEntity> categories;
  final ValueChanged<String> onChipTap;
  final ValueChanged<CategoryEntity> onCategoryTap;
  final VoidCallback onViewAllProducts;
  final ValueChanged<String> onRemoveHistory;
  final VoidCallback onClearHistory;

  static const List<_CategoryCardPalette> _palettes = <_CategoryCardPalette>[
    _CategoryCardPalette(
      background: Color(0xFFEAF6EC),
      iconBackground: Color(0xFFD6EDDA),
      iconColor: Color(0xFF0C831F),
      icon: Icons.eco_rounded,
    ),
    _CategoryCardPalette(
      background: Color(0xFFEDEFFB),
      iconBackground: Color(0xFFDDE2F7),
      iconColor: Color(0xFF3949AB),
      icon: Icons.egg_alt_rounded,
    ),
    _CategoryCardPalette(
      background: Color(0xFFFFF1E6),
      iconBackground: Color(0xFFFCE0CC),
      iconColor: Color(0xFFEE8F00),
      icon: Icons.fastfood_rounded,
    ),
    _CategoryCardPalette(
      background: Color(0xFFFFF7E0),
      iconBackground: Color(0xFFFBEBC0),
      iconColor: Color(0xFFD9A400),
      icon: Icons.grass_rounded,
    ),
    _CategoryCardPalette(
      background: Color(0xFFFCE9EF),
      iconBackground: Color(0xFFF7D4E0),
      iconColor: Color(0xFFD81B60),
      icon: Icons.local_fire_department_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final popularCategories = categories
        .where((category) => category.isActive && category.isParent)
        .take(6)
        .toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
      children: <Widget>[
        if (history.isNotEmpty) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Recent searches',
                  style: AppTextStyles.h3,
                ),
              ),
              GestureDetector(
                onTap: onClearHistory,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  'Clear all',
                  style: AppTextStyles.buttonSmall.copyWith(
                    color: AppColors.orderViolet,
                  ),
                ),
              ),
            ],
          ),
          const Gap(AppDimensions.spacing12),
          SizedBox(
            height: 38.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: history.length,
              separatorBuilder: (_, __) => Gap(10.w),
              itemBuilder: (context, index) {
                final query = history[index];
                return _RecentSearchChip(
                  query: query,
                  onTap: () => onChipTap(query),
                  onRemove: () => onRemoveHistory(query),
                );
              },
            ),
          ),
          const Gap(AppDimensions.spacing24),
        ],
        Text(
          'Popular categories',
          style: AppTextStyles.h3,
        ),
        const Gap(AppDimensions.spacing16),
        ...List<Widget>.generate(popularCategories.length, (index) {
          final category = popularCategories[index];
          final palette = _palettes[index % _palettes.length];
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: _PopularCategoryCard(
              category: category,
              palette: palette,
              onTap: () => onCategoryTap(category),
            )
                .animate()
                .fadeIn(
                  delay: (40 * index).ms,
                  duration: 280.ms,
                )
                .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
          );
        }),
        const Gap(AppDimensions.spacing8),
        _ViewAllProductsCard(onTap: onViewAllProducts),
      ],
    );
  }
}

class _RecentSearchChip extends StatelessWidget {
  const _RecentSearchChip({
    required this.query,
    required this.onTap,
    required this.onRemove,
  });

  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.orderVioletSurface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          border: Border.all(color: AppColors.orderVioletBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PhosphorIcon(
              PhosphorIcons.clockCounterClockwise,
              size: 15.sp,
              color: AppColors.orderViolet,
            ),
            Gap(7.w),
            Text(
              query,
              style: AppTextStyles.chip.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            Gap(8.w),
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: PhosphorIcon(
                PhosphorIcons.x,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularCategoryCard extends StatelessWidget {
  const _PopularCategoryCard({
    required this.category,
    required this.palette,
    required this.onTap,
  });

  final CategoryEntity category;
  final _CategoryCardPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = category.imageUrl ?? '';

    return Material(
      color: palette.background,
      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 92.h,
          child: Row(
            children: <Widget>[
              Gap(16.w),
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: palette.iconBackground,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Icon(
                  palette.icon,
                  size: 26.sp,
                  color: palette.iconColor,
                ),
              ),
              Gap(14.w),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(AppDimensions.spacing4),
                    Text(
                      '${category.productCount} items',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (imageUrl.isNotEmpty) ...<Widget>[
                SizedBox(
                  width: 88.w,
                  height: 92.h,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    memCacheWidth: 300,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                Gap(8.w),
              ],
              Container(
                width: 36.w,
                height: 36.w,
                margin: EdgeInsets.only(right: 14.w),
                decoration: const BoxDecoration(
                  color: AppColors.bgCard,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[AppShadows.cardShadow],
                ),
                child: Center(
                  child: PhosphorIcon(
                    PhosphorIcons.caretRightBold,
                    size: 16.sp,
                    color: AppColors.textPrimary,
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

class _ViewAllProductsCard extends StatelessWidget {
  const _ViewAllProductsCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40.w,
            height: 40.w,
            decoration: const BoxDecoration(
              color: AppColors.orderVioletSurface,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: PhosphorIcon(
                PhosphorIcons.sparkleFill,
                size: 20.sp,
                color: AppColors.orderViolet,
              ),
            ),
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  "Can't find what you're looking for?",
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(AppDimensions.spacing2),
                Text(
                  'Search from 10,000+ products',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          Gap(8.w),
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
              decoration: BoxDecoration(
                color: AppColors.orderVioletSurface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
              child: Text(
                'View all products',
                style: AppTextStyles.buttonSmall.copyWith(
                  color: AppColors.orderViolet,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebouncingState extends StatelessWidget {
  const _DebouncingState({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
      itemCount: 3,
      separatorBuilder: (_, __) => Gap(12.h),
      itemBuilder: (_, __) {
        return Row(
          children: <Widget>[
            const SkeletonLoader(height: 64, width: 64, radius: 12),
            Gap(12.w),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SkeletonLoader(height: 14, radius: 8),
                  Gap(AppDimensions.spacing8),
                  SkeletonLoader(height: 12, width: 100, radius: 8),
                  Gap(AppDimensions.spacing8),
                  SkeletonLoader(height: 12, width: 80, radius: 8),
                ],
              ),
            ),
            Gap(12.w),
            const SkeletonLoader(height: 36, width: 80, radius: 12),
          ],
        );
      },
    );
  }
}

class _SearchResultsState extends StatelessWidget {
  const _SearchResultsState({
    required this.pagingController,
    required this.displayProducts,
    required this.allProductsCount,
    required this.totalBackendCount,
    required this.sortOption,
    required this.filterState,
    required this.onSortTap,
    required this.onFilterTap,
    super.key,
  });

  final PagingController<int, ProductEntity> pagingController;
  final List<ProductEntity> displayProducts;
  final int allProductsCount;
  final int totalBackendCount;
  final _SortOption sortOption;
  final _FilterState filterState;
  final VoidCallback onSortTap;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    final isFiltered = !filterState.isDefault ||
        sortOption != _SortOption.relevance;

    // Result count label
    final displayCount = displayProducts.length;
    final countLabel = isFiltered
        ? '$displayCount result${displayCount == 1 ? '' : 's'} (filtered)'
        : (totalBackendCount == 1
            ? '1 result'
            : '$totalBackendCount results');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  countLabel,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              // Sort pill
              _SortFilterPill(
                icon: PhosphorIcons.caretDownBold,
                label: sortOption.label,
                isActive: sortOption != _SortOption.relevance,
                onTap: onSortTap,
              ),
              Gap(14.w),
              // Filter pill
              _SortFilterPill(
                icon: PhosphorIcons.slidersHorizontalBold,
                label: filterState.isDefault
                    ? null
                    : 'Filters ${filterState.activeCount}',
                isActive: !filterState.isDefault,
                onTap: onFilterTap,
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.divider),
        Expanded(
          child: _SortedFilteredList(
            displayProducts: displayProducts,
            pagingController: pagingController,
          ),
        ),
      ],
    );
  }
}

class _SortedFilteredList extends StatelessWidget {
  const _SortedFilteredList({
    required this.displayProducts,
    required this.pagingController,
  });

  final List<ProductEntity> displayProducts;
  final PagingController<int, ProductEntity> pagingController;

  @override
  Widget build(BuildContext context) {
    // Listen to paging status to show a loader at the bottom for new pages
    return ValueListenableBuilder<PagingState<int, ProductEntity>>(
      valueListenable: pagingController,
      builder: (context, pagingState, _) {
        final isLoadingMore = pagingState.nextPageKey != null &&
            pagingState.error == null;
        final hasError = pagingState.error != null &&
            pagingState.nextPageKey != null;

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
          itemCount:
              displayProducts.length + (isLoadingMore || hasError ? 1 : 0),
          separatorBuilder: (_, __) => Gap(12.h),
          itemBuilder: (context, index) {
            if (index >= displayProducts.length) {
              if (hasError) {
                return Center(
                  child: Text(
                    'Unable to load more results.',
                    style: AppTextStyles.bodySmall,
                  ),
                );
              }
              // Trigger next page load
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (pagingState.nextPageKey != null) {
                  pagingController.notifyPageRequestListeners(
                      pagingState.nextPageKey!);
                }
              });
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                ),
              );
            }
            return _SearchResultTile(product: displayProducts[index]);
          },
        );
      },
    );
  }
}

class _SortFilterPill extends StatelessWidget {
  const _SortFilterPill({
    required this.icon,
    required this.onTap,
    this.label,
    this.isActive = false,
  });

  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.orderViolet : AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.orderVioletSurface
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          border: Border.all(
            color: isActive
                ? AppColors.orderVioletBorder
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (label != null) ...<Widget>[
              Text(
                label!,
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Gap(4.w),
            ],
            PhosphorIcon(
              icon,
              size: 16.sp,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

// Helper row for filter toggles
class _FilterSwitchRow extends StatelessWidget {
  const _FilterSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.orderViolet,
          activeTrackColor: AppColors.orderVioletSurface,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}

class _SearchResultTile extends ConsumerWidget {
  const _SearchResultTile({required this.product});

  final ProductEntity product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = product.thumbnailUrl ??
        (product.images.isNotEmpty ? product.images.first : null);
    final quantity = ref.watch(cartItemQuantityProvider(product.id));
    // Purchase-limits: null == unrestricted (the common case, zero extra
    // visual/logic changes). Watched so this tile live-updates — e.g.
    // right after this exact tap pushes the product to its limit.
    final purchaseLimitStatus =
        ref.watch(purchaseLimitStatusProvider(product.id));
    final isAtLimit = purchaseLimitStatus?.isAtLimit ?? false;

    return InkWell(
      onTap: () => context.push('/product/${product.id}'),
      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          boxShadow: const <BoxShadow>[AppShadows.cardShadow],
        ),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              child: Container(
                width: 72.w,
                height: 72.w,
                color: AppColors.bgSection,
                child: imageUrl == null || imageUrl.isEmpty
                    ? Center(
                        child: PhosphorIcon(
                          PhosphorIcons.image,
                          color: AppColors.textDisabled,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        memCacheWidth: 300,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Center(
                          child: PhosphorIcon(
                            PhosphorIcons.imageBroken,
                            color: AppColors.textDisabled,
                          ),
                        ),
                      ),
              ),
            ),
            Gap(14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelLarge.copyWith(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Gap(AppDimensions.spacing4),
                  Text(
                    product.displayUnit,
                    style: AppTextStyles.bodySmall,
                  ),
                  const Gap(AppDimensions.spacing8),
                  RichText(
                    text: TextSpan(
                      text: '₹${product.effectivePrice.toStringAsFixed(0)}',
                      style: AppTextStyles.buttonMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                      children: <InlineSpan>[
                        if (product.isOnSale)
                          TextSpan(
                            text: '  ₹${product.price.toStringAsFixed(0)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Gap(12.w),
            QuantityControl(
              quantity: quantity,
              width: 84,
              height: 38,
              disableIncrement: isAtLimit,
              onAdd: product.inStock
                  ? () async {
                      // Re-checked fresh on every tap (ref.read, not the
                      // watched value above) so a stale cache can never
                      // let a mutation through — block before it ever
                      // reaches the network.
                      final status = ref
                          .read(purchaseLimitStatusProvider(product.id));
                      if (status?.isAtLimit ?? false) {
                        AppToast.show(
                          context,
                          'Maximum product order complete',
                        );
                        return;
                      }
                      final authGate = ref.read(authGateControllerProvider);
                      final allowed = await authGate.protectAddToCart(
                        context,
                        product,
                      );
                      if (!allowed || !context.mounted) {
                        return;
                      }
                      final result =
                          await ref.read(cartProvider.notifier).addItem(
                                product.id,
                                1,
                                product: product,
                              );
                      if (!context.mounted) {
                        return;
                      }
                      if (!result.isSuccess) {
                        showCartSnackBar(
                          context,
                          result.failure!.message,
                        );
                      }
                    }
                  : null,
              onIncrement: product.inStock && quantity < 50
                  ? () async {
                      // Re-checked fresh on every tap (ref.read, not the
                      // watched value above) so a stale cache can never
                      // let a mutation through — block before it ever
                      // reaches the network.
                      final status = ref
                          .read(purchaseLimitStatusProvider(product.id));
                      if (status?.isAtLimit ?? false) {
                        AppToast.show(
                          context,
                          'Maximum product order complete',
                        );
                        return;
                      }
                      final result = await ref
                          .read(cartProvider.notifier)
                          .updateItem(product.id, quantity + 1);
                      if (!context.mounted) {
                        return;
                      }
                      if (!result.isSuccess) {
                        showCartSnackBar(
                          context,
                          result.failure!.message,
                        );
                      }
                    }
                  : null,
              onDecrement: product.inStock && quantity > 0
                  ? () async {
                      final result = quantity == 1
                          ? await ref
                              .read(cartProvider.notifier)
                              .removeItem(product.id)
                          : await ref
                              .read(cartProvider.notifier)
                              .updateItem(product.id, quantity - 1);
                      if (!context.mounted) {
                        return;
                      }
                      if (!result.isSuccess) {
                        showCartSnackBar(
                          context,
                          result.failure!.message,
                        );
                      }
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState({
    required this.query,
    required this.suggestions,
    super.key,
  });

  final String query;
  final List<ProductEntity> suggestions;

  static const String _sadMagnifierSvg = '''
<svg width="132" height="132" viewBox="0 0 132 132" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="56" cy="56" r="32" stroke="#0C831F" stroke-width="8"/>
  <path d="M78 78L110 110" stroke="#0C831F" stroke-width="8" stroke-linecap="round"/>
  <circle cx="47" cy="50" r="4" fill="#0C831F"/>
  <circle cx="65" cy="50" r="4" fill="#0C831F"/>
  <path d="M44 69C48 63 64 63 68 69" stroke="#D32F2F" stroke-width="6" stroke-linecap="round"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 24.h),
      children: <Widget>[
        SvgPicture.string(
          _sadMagnifierSvg,
          width: 132.w,
          height: 132.w,
        ),
        const Gap(AppDimensions.spacing20),
        Text(
          'No results',
          textAlign: TextAlign.center,
          style: AppTextStyles.h2,
        ),
        const Gap(AppDimensions.spacing8),
        Text(
          'We could not find anything for "$query".',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium,
        ),
        if (suggestions.isNotEmpty) ...<Widget>[
          const Gap(AppDimensions.spacing24),
          Text(
            'You might like',
            style: AppTextStyles.h3,
          ),
          const Gap(AppDimensions.spacing12),
          SizedBox(
            height: 246.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => Gap(12.w),
              itemBuilder: (_, index) {
                return ProductCard(
                  product: suggestions[index],
                  style: ProductCardStyle.scroll,
                  onOptionsTap: suggestions[index].hasMultipleOptions
                      ? () => showProductOptionsSheet(context, suggestions[index])
                      : null,
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _SearchErrorState extends StatelessWidget {
  const _SearchErrorState({
    required this.message,
    required this.onRetry,
    super.key,
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
            PhosphorIcon(
              PhosphorIcons.warningCircle,
              size: 48,
              color: AppColors.warningOrange,
            ),
            const Gap(AppDimensions.spacing16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge,
            ),
            const Gap(AppDimensions.spacing16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              ),
              child: Text(
                'Retry',
                style: AppTextStyles.buttonMedium.copyWith(
                  color: AppColors.textOnGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
