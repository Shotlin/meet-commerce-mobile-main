import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/search/domain/entities/search_result_entity.dart';

abstract class SearchRepository {
  Future<Either<Failure, SearchResultEntity>> searchProducts({
    required String query,
    int page = 1,
    int limit = 20,
  });

  Future<void> saveHistory(String query);

  List<String> getHistory();

  Future<void> deleteHistory(String query);

  Future<void> clearHistory();
}
