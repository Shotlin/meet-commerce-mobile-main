import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/entities/notification_preference_entity.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/repositories/notification_repository.dart';

class GetPreferencesUseCase {
  const GetPreferencesUseCase(this._repository);

  final NotificationRepository _repository;

  Future<Either<Failure, NotificationPreferenceEntity>> call() {
    return _repository.getPreferences();
  }
}
