import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:bakaloo_flutter_app/features/auth/domain/entities/user_entity.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
abstract class UserModel with _$UserModel {
  const UserModel._();

  const factory UserModel({
    required String id,
    required String phone,
    required String role,
    String? name,
    String? email,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @JsonKey(name: 'loyalty_points') int? loyaltyPoints,
    @JsonKey(name: 'referral_code') String? referralCode,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  UserEntity toEntity() {
    return UserEntity(
      id: id,
      phone: phone,
      name: name,
      email: email,
      avatarUrl: avatarUrl,
      role: role,
      loyaltyPoints: loyaltyPoints,
      referralCode: referralCode,
    );
  }
}
