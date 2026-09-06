import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_entity.freezed.dart';

@freezed
abstract class UserEntity with _$UserEntity {
  const factory UserEntity({
    required String id,
    required String phone,
    required String role,
    String? name,
    String? email,
    String? avatarUrl,
    int? loyaltyPoints,
    String? referralCode,
  }) = _UserEntity;
}

class AuthEntity {
  const AuthEntity({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final UserEntity user;
}

class TokenEntity {
  const TokenEntity({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}
