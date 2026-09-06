import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/repositories/review_repository.dart';

class MyReviewsUseCase {
  const MyReviewsUseCase(this._repository);

  final ReviewRepository _repository;

  Future<Either<Failure, MyReviewsResult>> call({
    int page = 1,
    int limit = 10,
  }) {
    return _repository.getMyReviews(page: page, limit: limit);
  }
}
