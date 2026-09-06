import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/entities/review_eligibility_entity.dart';
import 'package:bakaloo_flutter_app/features/reviews/domain/repositories/review_repository.dart';

class EligibilityUseCase {
  const EligibilityUseCase(this._repository);

  final ReviewRepository _repository;

  Future<Either<Failure, ReviewEligibilityEntity>> call(String productId) {
    return _repository.checkEligibility(productId);
  }
}
