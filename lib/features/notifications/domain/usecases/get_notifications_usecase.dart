import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/repositories/notification_repository.dart';

class GetNotificationsUseCase {
  const GetNotificationsUseCase(this._repository);

  final NotificationRepository _repository;

  Future<Either<Failure, NotificationsPageEntity>> call({
    required int page,
    required int limit,
  }) {
    return _repository.getNotifications(
      page: page,
      limit: limit,
    );
  }
}
