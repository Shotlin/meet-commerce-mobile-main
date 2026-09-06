import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/entities/review_eligibility_entity.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/entities/review_entity.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

class ProductReviewsResult {
  const ProductReviewsResult({
    required this.reviews,
    required this.averageRating,
    required this.pagination,
  });

  final List<ReviewEntity> reviews;
  final double averageRating;
  final PaginationEntity pagination;
}

class MyReviewsResult {
  const MyReviewsResult({
    required this.reviews,
    required this.pagination,
  });

  final List<ReviewEntity> reviews;
  final PaginationEntity pagination;
}

class ReviewCreateParams {
  const ReviewCreateParams({
    required this.productId,
    required this.orderId,
    required this.rating,
    this.comment,
  });

  final String productId;
  final String orderId;
  final int rating;
  final String? comment;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'productId': productId,
      'orderId': orderId,
      'rating': rating,
      'comment': comment,
    }..removeWhere((key, value) => value == null || value == '');
  }
}

class ReviewUpdateParams {
  const ReviewUpdateParams({
    required this.rating,
    this.comment,
  });

  final int rating;
  final String? comment;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'rating': rating,
      'comment': comment,
    }..removeWhere((key, value) => value == null || value == '');
  }
}

abstract class ReviewRepository {
  Future<Either<Failure, ProductReviewsResult>> getReviews({
    required String productId,
    int page = 1,
    int limit = 10,
  });

  Future<Either<Failure, ReviewEligibilityEntity>> checkEligibility(
    String productId,
  );

  /// This user's existing reviews for one order, keyed by productId.
  Future<Either<Failure, Map<String, ({int rating, String? comment})>>>
      getOrderReviews(String orderId);

  Future<Either<Failure, ReviewEntity>> createReview(
    ReviewCreateParams params,
  );

  Future<Either<Failure, ReviewEntity>> updateReview(
    String reviewId,
    ReviewUpdateParams params,
  );

  Future<Either<Failure, void>> deleteReview(String reviewId);

  Future<Either<Failure, MyReviewsResult>> getMyReviews({
    int page = 1,
    int limit = 10,
  });
}
