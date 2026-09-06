import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/repositories/notification_repository.dart';

class RegisterFcmTokenUseCase {
  const RegisterFcmTokenUseCase(this._repository);

  final NotificationRepository _repository;

  Future<Either<Failure, Unit>> call({
    required String token,
    required String platform,
  }) {
    return _repository.registerFcmToken(
      token: token,
      platform: platform,
    );
  }
}
