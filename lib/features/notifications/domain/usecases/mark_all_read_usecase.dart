import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/repositories/notification_repository.dart';

class MarkAllReadUseCase {
  const MarkAllReadUseCase(this._repository);

  final NotificationRepository _repository;

  Future<Either<Failure, Unit>> call() {
    return _repository.markAllRead();
  }
}
