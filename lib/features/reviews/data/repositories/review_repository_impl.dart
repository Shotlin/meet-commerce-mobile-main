import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/reviews/data/datasources/review_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/entities/review_eligibility_entity.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/entities/review_entity.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/repositories/review_repository.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  const ReviewRepositoryImpl({
    required ReviewRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final ReviewRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, ProductReviewsResult>> getReviews({
    required String productId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final payload = await _remoteDataSource.getReviews(
        productId: productId,
        page: page,
        limit: limit,
      );
      return Right(
        ProductReviewsResult(
          reviews: payload.reviews,
          averageRating: payload.averageRating,
          pagination: payload.pagination,
        ),
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load reviews right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, ReviewEligibilityEntity>> checkEligibility(
    String productId,
  ) async {
    try {
      final eligibility = await _remoteDataSource.checkEligibility(productId);
      return Right(eligibility);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(
          message: 'Unable to check review eligibility right now.',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, ({int rating, String? comment})>>>
      getOrderReviews(String orderId) async {
    try {
      final result = await _remoteDataSource.getOrderReviews(orderId);
      return Right(result);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load your reviews for this order.'),
      );
    }
  }

  @override
  Future<Either<Failure, ReviewEntity>> createReview(
    ReviewCreateParams params,
  ) async {
    try {
      final review = await _remoteDataSource.createReview(params.toJson());
      return Right(review);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to submit review right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, ReviewEntity>> updateReview(
    String reviewId,
    ReviewUpdateParams params,
  ) async {
    try {
      final review = await _remoteDataSource.updateReview(
        reviewId,
        params.toJson(),
      );
      return Right(review);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to update review right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> deleteReview(String reviewId) async {
    try {
      await _remoteDataSource.deleteReview(reviewId);
      return const Right(null);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to delete review right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, MyReviewsResult>> getMyReviews({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final payload = await _remoteDataSource.getMyReviews(
        page: page,
        limit: limit,
      );
      return Right(
        MyReviewsResult(
          reviews: payload.reviews,
          pagination: payload.pagination,
        ),
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load your reviews right now.'),
      );
    }
  }
}
