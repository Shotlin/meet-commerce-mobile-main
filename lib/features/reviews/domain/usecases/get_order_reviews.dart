import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/repositories/review_repository.dart';

class GetOrderReviewsUseCase {
  const GetOrderReviewsUseCase(this._repository);

  final ReviewRepository _repository;

  Future<Either<Failure, Map<String, ({int rating, String? comment})>>> call(
    String orderId,
  ) {
    return _repository.getOrderReviews(orderId);
  }
}
