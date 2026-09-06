import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/products/data/models/product_model.dart';
import 'package:bakaloo_flutter_app/features/search/data/datasources/search_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/search/data/local/search_history_datasource.dart';
import 'package:bakaloo_flutter_app/features/search/domain/entities/search_result_entity.dart';
import 'package:bakaloo_flutter_app/features/search/domain/repositories/search_repository.dart';

class SearchRepositoryImpl implements SearchRepository {
  const SearchRepositoryImpl({
    required SearchRemoteDataSource remoteDataSource,
    required SearchHistoryDataSource historyDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _historyDataSource = historyDataSource;

  final SearchRemoteDataSource _remoteDataSource;
  final SearchHistoryDataSource _historyDataSource;

  @override
  Future<Either<Failure, SearchResultEntity>> searchProducts({
    required String query,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final result = await _remoteDataSource.searchProducts(
        query: query,
        page: page,
        limit: limit,
      );

      return Right(
        SearchResultEntity(
          products: result.products
              .map((ProductModel product) => product.toEntity())
              .toList(),
          suggestions: result.suggestions
              .map((ProductModel product) => product.toEntity())
              .toList(),
          total: result.pagination.total,
          pagination: result.pagination,
        ),
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to search products right now.'),
      );
    }
  }

  @override
  Future<void> saveHistory(String query) {
    return _historyDataSource.save(query);
  }

  @override
  List<String> getHistory() {
    return _historyDataSource.getAll();
  }

  @override
  Future<void> deleteHistory(String query) {
    return _historyDataSource.delete(query);
  }

  @override
  Future<void> clearHistory() {
    return _historyDataSource.clearAll();
  }
}
