import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_stats_entity.freezed.dart';

@freezed
abstract class UserStatsEntity with _$UserStatsEntity {
  const factory UserStatsEntity({
    @Default(0) int totalOrders,
    @Default(0) double totalSpent,
    @Default(0) int loyaltyPoints,
  }) = _UserStatsEntity;
}
