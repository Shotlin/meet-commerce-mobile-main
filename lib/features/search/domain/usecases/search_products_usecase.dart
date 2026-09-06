import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/search/domain/entities/search_result_entity.dart';
import 'package:bakaloo_flutter_app/features/search/domain/repositories/search_repository.dart';

class SearchProductsUseCase {
  const SearchProductsUseCase(this._repository);

  final SearchRepository _repository;

  Future<Either<Failure, SearchResultEntity>> call({
    required String query,
    int page = 1,
    int limit = 20,
  }) {
    return _repository.searchProducts(
      query: query,
      page: page,
      limit: limit,
    );
  }
}
