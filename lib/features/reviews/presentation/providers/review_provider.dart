import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/reviews/data/datasources/review_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/reviews/data/repositories/review_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/entities/review_eligibility_entity.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/entities/review_entity.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/repositories/review_repository.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/usecases/create.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/usecases/delete.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/usecases/eligibility.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/usecases/get_order_reviews.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/usecases/get_reviews.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/usecases/my_reviews.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/usecases/update.dart';

part 'review_provider.g.dart';

class ReviewActionResult {
  const ReviewActionResult({
    this.failure,
    this.review,
  });

  final Failure? failure;
  final ReviewEntity? review;

  bool get isSuccess => failure == null;
}

final reviewRemoteDataSourceProvider =
    Provider<ReviewRemoteDataSource>((Ref ref) {
  return ReviewRemoteDataSource(ref.watch(apiClientProvider));
});

final reviewRepositoryProvider = Provider<ReviewRepository>((Ref ref) {
  return ReviewRepositoryImpl(
    remoteDataSource: ref.watch(reviewRemoteDataSourceProvider),
  );
});

final getReviewsUseCaseProvider = Provider<GetReviewsUseCase>((Ref ref) {
  return GetReviewsUseCase(ref.watch(reviewRepositoryProvider));
});

final reviewEligibilityUseCaseProvider =
    Provider<EligibilityUseCase>((Ref ref) {
  return EligibilityUseCase(ref.watch(reviewRepositoryProvider));
});

final getOrderReviewsUseCaseProvider =
    Provider<GetOrderReviewsUseCase>((Ref ref) {
  return GetOrderReviewsUseCase(ref.watch(reviewRepositoryProvider));
});

final createReviewUseCaseProvider = Provider<CreateUseCase>((Ref ref) {
  return CreateUseCase(ref.watch(reviewRepositoryProvider));
});

final updateReviewUseCaseProvider = Provider<UpdateUseCase>((Ref ref) {
  return UpdateUseCase(ref.watch(reviewRepositoryProvider));
});

final deleteReviewUseCaseProvider = Provider<DeleteUseCase>((Ref ref) {
  return DeleteUseCase(ref.watch(reviewRepositoryProvider));
});

final myReviewsUseCaseProvider = Provider<MyReviewsUseCase>((Ref ref) {
  return MyReviewsUseCase(ref.watch(reviewRepositoryProvider));
});

@riverpod
Future<ReviewEligibilityEntity> reviewEligibility(
  Ref ref,
  String productId,
) async {
  final result =
      await ref.read(reviewEligibilityUseCaseProvider).call(productId);
  return result.fold(
    (failure) => throw StateError(failure.message),
    (eligibility) => eligibility,
  );
}

@riverpod
Future<Map<String, ({int rating, String? comment})>> orderReviews(
  Ref ref,
  String orderId,
) async {
  final result = await ref.read(getOrderReviewsUseCaseProvider).call(orderId);
  return result.fold(
    (failure) => throw StateError(failure.message),
    (reviews) => reviews,
  );
}

@Riverpod(keepAlive: true)
class ReviewNotifier extends _$ReviewNotifier {
  @override
  AsyncValue<void> build() {
    return const AsyncData(null);
  }

  Future<Either<Failure, ProductReviewsResult>> getProductReviews({
    required String productId,
    int page = 1,
    int limit = 10,
  }) {
    return ref.read(getReviewsUseCaseProvider).call(
          productId: productId,
          page: page,
          limit: limit,
        );
  }

  Future<Either<Failure, MyReviewsResult>> getMyReviews({
    int page = 1,
    int limit = 10,
  }) {
    return ref.read(myReviewsUseCaseProvider).call(
          page: page,
          limit: limit,
        );
  }

  Future<ReviewActionResult> createReview(ReviewCreateParams params) async {
    state = const AsyncLoading<void>();
    final result = await ref.read(createReviewUseCaseProvider).call(params);
    return result.fold(
      (failure) {
        state = AsyncError<void>(failure, StackTrace.current);
        return ReviewActionResult(failure: failure);
      },
      (review) {
        state = const AsyncData<void>(null);
        return ReviewActionResult(review: review);
      },
    );
  }

  Future<ReviewActionResult> updateReview(
    String reviewId,
    ReviewUpdateParams params,
  ) async {
    state = const AsyncLoading<void>();
    final result =
        await ref.read(updateReviewUseCaseProvider).call(reviewId, params);
    return result.fold(
      (failure) {
        state = AsyncError<void>(failure, StackTrace.current);
        return ReviewActionResult(failure: failure);
      },
      (review) {
        state = const AsyncData<void>(null);
        return ReviewActionResult(review: review);
      },
    );
  }

  Future<ReviewActionResult> deleteReview(String reviewId) async {
    state = const AsyncLoading<void>();
    final result = await ref.read(deleteReviewUseCaseProvider).call(reviewId);
    return result.fold(
      (failure) {
        state = AsyncError<void>(failure, StackTrace.current);
        return ReviewActionResult(failure: failure);
      },
      (_) {
        state = const AsyncData<void>(null);
        return const ReviewActionResult();
      },
    );
  }
}
