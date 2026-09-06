import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_entity.freezed.dart';

@freezed
abstract class NotificationEntity with _$NotificationEntity {
  const NotificationEntity._();

  const factory NotificationEntity({
    required String id,
    required String type,
    required String title,
    required String body,
    required DateTime createdAt,
    @Default(false) bool isRead,
    DateTime? readAt,
    String? imageUrl,
    String? deepLink,
    @Default(<String, dynamic>{}) Map<String, dynamic> data,
  }) = _NotificationEntity;

  bool get isUnread => !isRead;
}
