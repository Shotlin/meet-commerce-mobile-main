import 'dart:io';

import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/auth/domain/entities/user_entity.dart';
import 'package:bakaloo_flutter_app/features/profile/domain/entities/user_stats_entity.dart';

class ProfileData {
  const ProfileData({
    required this.user,
    this.birthday,
  });

  final UserEntity user;
  final DateTime? birthday;

  ProfileData copyWith({
    UserEntity? user,
    DateTime? birthday,
    bool clearBirthday = false,
  }) {
    return ProfileData(
      user: user ?? this.user,
      birthday: clearBirthday ? null : birthday ?? this.birthday,
    );
  }
}

class UpdateProfileParams {
  const UpdateProfileParams({
    this.name,
    this.email,
    this.birthday,
  });

  final String? name;
  final String? email;
  final DateTime? birthday;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name?.trim(),
      'email': email?.trim(),
      'birthday': _formatBirthday(birthday),
    }..removeWhere((key, value) => value == null || value == '');
    return map;
  }

  String? _formatBirthday(DateTime? value) {
    if (value == null) {
      return null;
    }
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

abstract class ProfileRepository {
  Future<Either<Failure, ProfileData>> getProfile();

  Future<Either<Failure, ProfileData>> updateProfile(
    UpdateProfileParams params,
  );

  Future<Either<Failure, String>> uploadAvatar(File imageFile);

  Future<Either<Failure, UserStatsEntity>> getStats();
}
