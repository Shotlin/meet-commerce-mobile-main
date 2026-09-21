import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';
import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/features/auth/domain/entities/user_entity.dart';
import 'package:bakaloo_flutter_app/features/profile/data/datasources/user_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/profile/domain/entities/user_stats_entity.dart';
import 'package:bakaloo_flutter_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:bakaloo_flutter_app/features/profile/domain/usecases/get_profile.dart';
import 'package:bakaloo_flutter_app/features/profile/domain/usecases/get_stats.dart';
import 'package:bakaloo_flutter_app/features/profile/domain/usecases/update_profile.dart';
import 'package:bakaloo_flutter_app/features/profile/domain/usecases/upload_avatar.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/routing/app_router.dart';

part 'profile_provider.g.dart';

final userRemoteDataSourceProvider = Provider<UserRemoteDataSource>((Ref ref) {
  return UserRemoteDataSource(ref.watch(apiClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((Ref ref) {
  return ProfileRepositoryImpl(
    remoteDataSource: ref.watch(userRemoteDataSourceProvider),
  );
});

final getProfileUseCaseProvider = Provider<GetProfileUseCase>((Ref ref) {
  return GetProfileUseCase(ref.watch(profileRepositoryProvider));
});

final updateProfileUseCaseProvider = Provider<UpdateProfileUseCase>((Ref ref) {
  return UpdateProfileUseCase(ref.watch(profileRepositoryProvider));
});

final uploadAvatarUseCaseProvider = Provider<UploadAvatarUseCase>((Ref ref) {
  return UploadAvatarUseCase(ref.watch(profileRepositoryProvider));
});

final getStatsUseCaseProvider = Provider<GetStatsUseCase>((Ref ref) {
  return GetStatsUseCase(ref.watch(profileRepositoryProvider));
});

class ProfileActionResult {
  const ProfileActionResult({
    this.failure,
  });

  final Failure? failure;

  bool get isSuccess => failure == null;
}

@Riverpod(keepAlive: true)
class ProfileNotifier extends _$ProfileNotifier {
  @override
  Future<ProfileData> build() async {
    // Cache-then-network, same pattern as AddressNotifier and the existing
    // theme/home content caching in remote_theme_provider.dart: show the
    // last-known profile instantly instead of a blank/loading profile tab
    // on every cold start, then silently refresh underneath.
    final cached = _readCachedProfile();
    if (cached != null) {
      debugPrint(
        '[ProfileNotifier] served profile from cache at '
        't=${DateTime.now()}; refreshing in background',
      );
      unawaited(_refreshInBackground());
      return cached;
    }

    final result = await ref.read(getProfileUseCaseProvider).call();
    return result.fold(
      (failure) {
        final fallbackUser = ref.read(currentUserProvider);
        if (fallbackUser != null) {
          return ProfileData(user: fallbackUser);
        }
        throw StateError(failure.message);
      },
      (profile) {
        _writeCache(profile);
        return profile;
      },
    );
  }

  Future<void> _refreshInBackground() async {
    final result = await ref.read(getProfileUseCaseProvider).call();
    result.fold(
      (failure) {
        debugPrint('[ProfileNotifier] background refresh failed: '
            '${failure.message}');
      },
      (profile) {
        if (!ref.mounted) {
          return;
        }
        // ProfileData itself has no value equality (plain class, no ==
        // override) — compare the fields that do (UserEntity is freezed)
        // so an unchanged refresh doesn't still trigger a rebuild.
        final current = _currentProfile;
        if (current == null ||
            current.user != profile.user ||
            current.birthday != profile.birthday) {
          state = AsyncData(profile);
        }
        _writeCache(profile);
      },
    );
  }

  ProfileData? _readCachedProfile() {
    try {
      final raw = HiveService.settingsBox.get(StorageKeys.cacheUserProfile);
      if (raw is! String || raw.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return _profileFromJson(Map<String, dynamic>.from(decoded));
    } catch (error) {
      debugPrint('[ProfileNotifier] cache read failed: $error');
      return null;
    }
  }

  void _writeCache(ProfileData profile) {
    try {
      final encoded = jsonEncode(_profileToJson(profile));
      unawaited(
        HiveService.settingsBox.put(StorageKeys.cacheUserProfile, encoded),
      );
    } catch (error) {
      debugPrint('[ProfileNotifier] cache write failed: $error');
    }
  }

  Future<ProfileActionResult> fetchProfile() async {
    state = const AsyncLoading<ProfileData>();

    final result = await ref.read(getProfileUseCaseProvider).call();
    return result.fold(
      (failure) {
        state = AsyncError<ProfileData>(
          StateError(failure.message),
          StackTrace.current,
        );
        return ProfileActionResult(failure: failure);
      },
      (profile) {
        state = AsyncData(profile);
        _writeCache(profile);
        return const ProfileActionResult();
      },
    );
  }

  Future<ProfileActionResult> updateProfile({
    String? name,
    String? email,
    DateTime? birthday,
  }) async {
    final result = await ref.read(updateProfileUseCaseProvider).call(
          UpdateProfileParams(
            name: name,
            email: email,
            birthday: birthday,
          ),
        );

    return result.fold(
      (failure) => ProfileActionResult(failure: failure),
      (profile) {
        state = AsyncData(profile);
        _writeCache(profile);
        ref.invalidate(userStatsProvider);
        // Keep the auth session's cached identity in sync — otherwise this
        // save "reverts" on the next app restart (see syncCachedUser's doc
        // comment in auth_notifier.dart for why).
        unawaited(
          ref.read(authStateProvider.notifier).syncCachedUser(profile.user),
        );
        return const ProfileActionResult();
      },
    );
  }

  Future<ProfileActionResult> uploadAvatar(File imageFile) async {
    final result = await ref.read(uploadAvatarUseCaseProvider).call(imageFile);

    return result.fold(
      (failure) => ProfileActionResult(failure: failure),
      (avatarUrl) {
        final currentProfile = _currentProfile ?? _fallbackProfile;
        if (currentProfile == null) {
          return const ProfileActionResult();
        }

        final updated = currentProfile.copyWith(
          user: currentProfile.user.copyWith(avatarUrl: avatarUrl),
        );
        state = AsyncData(updated);
        _writeCache(updated);
        return const ProfileActionResult();
      },
    );
  }

  Future<ProfileActionResult> logout() async {
    await ref.read(authNotifierProvider.notifier).logout();
    ref
      ..invalidate(userStatsProvider)
      ..invalidateSelf();
    return const ProfileActionResult();
  }

  Future<ProfileActionResult> deleteAccount() async {
    try {
      await ref.read(apiClientProvider).deleteAccount();
      await ref.read(authNotifierProvider.notifier).logout();
      ref
        ..invalidate(userStatsProvider)
        ..invalidateSelf();
      return const ProfileActionResult();
    } on DioException catch (error) {
      return ProfileActionResult(failure: handleDioError(error));
    } catch (_) {
      return const ProfileActionResult(
        failure: UnknownFailure(
          message: 'Unable to delete account right now.',
        ),
      );
    }
  }

  ProfileData? get _currentProfile => switch (state) {
        AsyncData(:final value) => value,
        _ => null,
      };

  ProfileData? get _fallbackProfile {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      return null;
    }
    return ProfileData(user: user);
  }
}

@riverpod
Future<UserStatsEntity> userStats(Ref ref) async {
  final result = await ref.read(getStatsUseCaseProvider).call();
  return result.fold(
    (failure) => throw StateError(failure.message),
    (stats) => stats,
  );
}

/// Hand-written (no codegen) JSON mapping for the on-device profile cache.
/// Neither [ProfileData] nor [UserEntity] has `toJson`/`fromJson` — mirrors
/// them field-for-field rather than pulling in build_runner just for local
/// cache persistence.
Map<String, dynamic> _profileToJson(ProfileData profile) => <String, dynamic>{
      'id': profile.user.id,
      'phone': profile.user.phone,
      'role': profile.user.role,
      'name': profile.user.name,
      'email': profile.user.email,
      'avatarUrl': profile.user.avatarUrl,
      'loyaltyPoints': profile.user.loyaltyPoints,
      'referralCode': profile.user.referralCode,
      'birthday': profile.birthday?.toIso8601String(),
    };

ProfileData _profileFromJson(Map<String, dynamic> json) {
  final birthdayRaw = json['birthday'] as String?;
  return ProfileData(
    user: UserEntity(
      id: json['id'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'CUSTOMER',
      name: json['name'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      loyaltyPoints: (json['loyaltyPoints'] as num?)?.toInt(),
      referralCode: json['referralCode'] as String?,
    ),
    birthday: birthdayRaw == null ? null : DateTime.tryParse(birthdayRaw),
  );
}
