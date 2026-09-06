import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/entities/review_entity.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/repositories/review_repository.dart';

class CreateUseCase {
  const CreateUseCase(this._repository);

  final ReviewRepository _repository;

  Future<Either<Failure, ReviewEntity>> call(ReviewCreateParams params) {
    return _repository.createReview(params);
  }
}
