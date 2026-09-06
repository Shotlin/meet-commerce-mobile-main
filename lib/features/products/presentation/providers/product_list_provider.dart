import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/features/categories/presentation/providers/category_provider.dart';
import 'package:bakaloo_flutter_app/features/products/data/datasources/product_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/products/data/local/product_local_datasource.dart';
import 'package:bakaloo_flutter_app/features/products/data/repositories/product_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/products/domain/repositories/product_repository.dart';
import 'package:bakaloo_flutter_app/features/products/domain/usecases/get_deals.dart';
import 'package:bakaloo_flutter_app/features/products/domain/usecases/get_featured.dart';
import 'package:bakaloo_flutter_app/features/products/domain/usecases/get_new_arrivals.dart';
import 'package:bakaloo_flutter_app/features/products/domain/usecases/get_products.dart';

part 'product_list_provider.g.dart';

@immutable
class ProductListParams {
  const ProductListParams({
    this.categoryId,
    this.title = 'Products',
  });

  final String? categoryId;
  final String title;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ProductListParams &&
            runtimeType == other.runtimeType &&
            categoryId == other.categoryId &&
            title == other.title;
  }

  @override
  int get hashCode => Object.hash(categoryId, title);
}

@immutable
class ProductListViewState {
  const ProductListViewState({
    required this.items,
    required this.page,
    required this.hasMore,
    this.isLoadingMore = false,
    this.isStale = false,
    this.paginationMessage,
    this.newItemCount = 0,
  });

  final List<ProductEntity> items;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isStale;
  final String? paginationMessage;
  // How many items were appended in the last loadMore — used for stagger animation.
  final int newItemCount;

  ProductListViewState copyWith({
    List<ProductEntity>? items,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isStale,
    String? paginationMessage,
    bool clearPaginationMessage = false,
    int? newItemCount,
  }) {
    return ProductListViewState(
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isStale: isStale ?? this.isStale,
      paginationMessage: clearPaginationMessage
          ? null
          : paginationMessage ?? this.paginationMessage,
      newItemCount: newItemCount ?? 0,
    );
  }
}

final productRemoteDataSourceProvider = Provider<ProductRemoteDataSource>((
  Ref ref,
) {
  return ProductRemoteDataSource(ref.watch(apiClientProvider));
});

final productLocalDataSourceProvider = Provider<ProductLocalDataSource>((
  Ref ref,
) {
  return const ProductLocalDataSource();
});

final productRepositoryProvider = Provider<ProductRepository>((Ref ref) {
  return ProductRepositoryImpl(
    remoteDataSource: ref.watch(productRemoteDataSourceProvider),
    localDataSource: ref.watch(productLocalDataSourceProvider),
  );
});

final getProductsUseCaseProvider = Provider<GetProductsUseCase>((Ref ref) {
  return GetProductsUseCase(ref.watch(productRepositoryProvider));
});

final getFeaturedUseCaseProvider = Provider<GetFeaturedUseCase>((Ref ref) {
  return GetFeaturedUseCase(ref.watch(productRepositoryProvider));
});

final getNewArrivalsUseCaseProvider = Provider<GetNewArrivalsUseCase>((
  Ref ref,
) {
  return GetNewArrivalsUseCase(ref.watch(productRepositoryProvider));
});

final getDealsUseCaseProvider = Provider<GetDealsUseCase>((Ref ref) {
  return GetDealsUseCase(ref.watch(productRepositoryProvider));
});

@riverpod
class ProductListNotifier extends _$ProductListNotifier {
  // Load 20 products initially, 20 more per infinite-scroll trigger.
  static const int _initialLimit = 20;
  static const int _pageLimit = 20;

  final List<ProductEntity> _items = <ProductEntity>[];
  late ProductListParams _params;
  int _page = 1;
  bool _hasMore = true;

  @override
  Future<ProductListViewState> build(ProductListParams params) async {
    _params = params;
    _items.clear();
    _page = 1;
    _hasMore = true;
    return _fetchPage(params, reset: true);
  }

  Future<void> loadMore() async {
    final currentState = state.asData?.value;
    if (currentState == null || currentState.isLoadingMore || !_hasMore) {
      return;
    }

    state = AsyncData(
      currentState.copyWith(
        isLoadingMore: true,
        clearPaginationMessage: true,
      ),
    );

    _page += 1;
    try {
      final nextState = await _fetchPage(_params);
      state = AsyncData(nextState);
    } catch (error) {
      _page -= 1;
      state = AsyncData(
        currentState.copyWith(
          isLoadingMore: false,
          paginationMessage: _messageFromError(error),
        ),
      );
    }
  }

  void refresh() {
    ref.invalidateSelf();
  }

  Future<ProductListViewState> _fetchPage(
    ProductListParams params, {
    bool reset = false,
  }) async {
    final limit = reset ? _initialLimit : _pageLimit;
    final result = params.categoryId == null
        ? await ref.read(getProductsUseCaseProvider).call(
              page: _page,
              limit: limit,
            )
        : await ref.read(getCategoryProductsUseCaseProvider).call(
              categoryId: params.categoryId!,
              page: _page,
              limit: limit,
            );

    return result.fold((failure) {
      throw StateError(failure.message);
    }, (pageResult) {
      if (reset) {
        _items.clear();
      }

      final newCount = pageResult.items.length;
      _items.addAll(pageResult.items);
      final totalPages = pageResult.pagination.totalPages;
      _hasMore = totalPages > 0
          ? pageResult.pagination.page < totalPages
          : pageResult.items.length >= limit;

      return ProductListViewState(
        items: List<ProductEntity>.unmodifiable(_items),
        page: _page,
        hasMore: _hasMore,
        isLoadingMore: false,
        isStale: pageResult.isStale,
        newItemCount: reset ? 0 : newCount,
      );
    });
  }

  String _messageFromError(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }
    return 'Unable to load more products right now.';
  }
}
