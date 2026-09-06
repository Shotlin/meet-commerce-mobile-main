import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/analytics/analytics_service.dart';
import 'package:bakaloo_flutter_app/core/constants/app_constants.dart';
import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/utils/debouncer.dart';
import 'package:bakaloo_flutter_app/features/search/data/datasources/search_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/search/data/local/search_history_datasource.dart';
import 'package:bakaloo_flutter_app/features/search/data/repositories/search_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/search/domain/entities/search_result_entity.dart';
import 'package:bakaloo_flutter_app/features/search/domain/repositories/search_repository.dart';
import 'package:bakaloo_flutter_app/features/search/domain/usecases/clear_history.dart';
import 'package:bakaloo_flutter_app/features/search/domain/usecases/save_history.dart';
import 'package:bakaloo_flutter_app/features/search/domain/usecases/search_products_usecase.dart';

part 'search_provider.g.dart';

final searchRemoteDataSourceProvider = Provider<SearchRemoteDataSource>((
  Ref ref,
) {
  return SearchRemoteDataSource(ref.watch(apiClientProvider));
});

final searchHistoryDataSourceProvider = Provider<SearchHistoryDataSource>((
  Ref ref,
) {
  return const SearchHistoryDataSource();
});

final searchRepositoryProvider = Provider<SearchRepository>((Ref ref) {
  return SearchRepositoryImpl(
    remoteDataSource: ref.watch(searchRemoteDataSourceProvider),
    historyDataSource: ref.watch(searchHistoryDataSourceProvider),
  );
});

final searchProductsUseCaseProvider =
    Provider<SearchProductsUseCase>((Ref ref) {
  return SearchProductsUseCase(ref.watch(searchRepositoryProvider));
});

final saveHistoryUseCaseProvider = Provider<SaveHistoryUseCase>((Ref ref) {
  return SaveHistoryUseCase(ref.watch(searchRepositoryProvider));
});

final clearHistoryUseCaseProvider = Provider<ClearHistoryUseCase>((Ref ref) {
  return ClearHistoryUseCase(ref.watch(searchRepositoryProvider));
});

@riverpod
class SearchNotifier extends _$SearchNotifier {
  final Debouncer _debouncer = Debouncer(
    delay: const Duration(milliseconds: AppConstants.searchDebounceMs),
  );

  String _currentQuery = '';

  String get currentQuery => _currentQuery;

  @override
  Future<SearchResultEntity> build() {
    ref.onDispose(_debouncer.dispose);
    return Future<SearchResultEntity>.value(SearchResultEntity.empty());
  }

  void onQueryChanged(String query) {
    final trimmedQuery = query.trim();
    _currentQuery = trimmedQuery;

    if (trimmedQuery.isEmpty) {
      _debouncer.cancel();
      state = AsyncData(SearchResultEntity.empty());
      return;
    }

    state = const AsyncLoading<SearchResultEntity>();
    _debouncer.run(() {
      unawaited(_search(trimmedQuery));
    });
  }

  Future<void> retry() async {
    if (_currentQuery.isEmpty) {
      return;
    }

    state = const AsyncLoading<SearchResultEntity>();
    await _search(_currentQuery);
  }

  Future<SearchResultEntity> searchPage({
    required String query,
    required int page,
    int limit = AppConstants.paginationLimit,
  }) async {
    final result = await ref.read(searchProductsUseCaseProvider).call(
          query: query,
          page: page,
          limit: limit,
        );

    return result.fold((failure) {
      throw StateError(failure.message);
    }, (data) {
      return data;
    });
  }

  Future<void> _search(String query) async {
    unawaited(ref.read(saveHistoryUseCaseProvider).call(query));

    final result = await ref.read(searchProductsUseCaseProvider).call(
          query: query,
          page: 1,
          limit: AppConstants.paginationLimit,
        );

    if (query != _currentQuery) {
      return;
    }

    state = result.fold(
      (failure) => AsyncError<SearchResultEntity>(
        StateError(failure.message),
        StackTrace.current,
      ),
      (data) {
        final resultCount = data.total > 0 ? data.total : data.products.length;
        unawaited(
          ref.read(analyticsServiceProvider).logSearch(
                query,
                resultCount,
              ),
        );
        return AsyncData<SearchResultEntity>(data);
      },
    );
  }
}
