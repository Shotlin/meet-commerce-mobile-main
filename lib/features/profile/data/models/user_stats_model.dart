import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:bakaloo_flutter_app/features/profile/domain/entities/user_stats_entity.dart';

part 'user_stats_model.freezed.dart';
part 'user_stats_model.g.dart';

@freezed
abstract class UserStatsModel with _$UserStatsModel {
  const UserStatsModel._();

  const factory UserStatsModel({
    @JsonKey(name: 'total_orders') @Default(0) int totalOrders,
    @JsonKey(name: 'total_spent', fromJson: _toDouble)
    @Default(0)
    double totalSpent,
    @JsonKey(name: 'loyalty_points') @Default(0) int loyaltyPoints,
  }) = _UserStatsModel;

  factory UserStatsModel.fromJson(Map<String, dynamic> json) =>
      _$UserStatsModelFromJson(json);

  UserStatsEntity toEntity() {
    return UserStatsEntity(
      totalOrders: totalOrders,
      totalSpent: totalSpent,
      loyaltyPoints: loyaltyPoints,
    );
  }
}

double _toDouble(Object? raw) {
  if (raw is num) {
    return raw.toDouble();
  }
  if (raw is String && raw.trim().isNotEmpty) {
    return double.tryParse(raw.trim()) ?? 0;
  }
  return 0;
}
