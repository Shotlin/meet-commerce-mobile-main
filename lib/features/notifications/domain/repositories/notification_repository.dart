import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/entities/notification_entity.dart';
import 'package:bakaloo_flutter_app/features/notifications/domain/entities/notification_preference_entity.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

class NotificationsPageEntity {
  const NotificationsPageEntity({
    required this.items,
    required this.pagination,
    required this.unreadCount,
  });

  final List<NotificationEntity> items;
  final PaginationEntity pagination;
  final int unreadCount;
}

abstract class NotificationRepository {
  Future<Either<Failure, NotificationsPageEntity>> getNotifications({
    required int page,
    required int limit,
  });

  Future<Either<Failure, Unit>> markRead(String notificationId);

  Future<Either<Failure, Unit>> markAllRead();

  Future<Either<Failure, Unit>> markCampaignOpened(String campaignId);

  Future<Either<Failure, Unit>> deleteNotification(String notificationId);

  Future<Either<Failure, NotificationPreferenceEntity>> getPreferences();

  Future<Either<Failure, Unit>> registerFcmToken({
    required String token,
    required String platform,
  });

  Future<Either<Failure, NotificationPreferenceEntity>> updatePreferences(
    NotificationPreferenceEntity preferences,
  );
}
