import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/repositories/review_repository.dart';

class GetReviewsUseCase {
  const GetReviewsUseCase(this._repository);

  final ReviewRepository _repository;

  Future<Either<Failure, ProductReviewsResult>> call({
    required String productId,
    int page = 1,
    int limit = 10,
  }) {
    return _repository.getReviews(
      productId: productId,
      page: page,
      limit: limit,
    );
  }
}
