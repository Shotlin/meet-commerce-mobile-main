import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_preference_entity.freezed.dart';

@freezed
abstract class NotificationPreferenceEntity
    with _$NotificationPreferenceEntity {
  const factory NotificationPreferenceEntity({
    @Default(true) bool orderUpdates,
    @Default(true) bool promotions,
    @Default(true) bool newProducts,
    @Default(true) bool priceDrops,
    @Default(true) bool deliveryUpdates,
  }) = _NotificationPreferenceEntity;
}
