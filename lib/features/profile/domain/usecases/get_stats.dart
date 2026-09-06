import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/profile/domain/entities/user_stats_entity.dart';
import 'package:bakaloo_flutter_app/features/profile/domain/repositories/profile_repository.dart';

class GetStatsUseCase {
  const GetStatsUseCase(this._repository);

  final ProfileRepository _repository;

  Future<Either<Failure, UserStatsEntity>> call() {
    return _repository.getStats();
  }
}
