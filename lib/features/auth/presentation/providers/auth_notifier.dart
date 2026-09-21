import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';
import 'package:bakaloo_flutter_app/core/diagnostics/crash_reporter.dart';
import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/core/notifications/fcm_token_helper.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_service.dart';
import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/auth/data/models/user_model.dart';
import 'package:bakaloo_flutter_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/auth/domain/entities/user_entity.dart';
import 'package:bakaloo_flutter_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:bakaloo_flutter_app/features/auth/domain/usecases/logout_usecase.dart';
import 'package:bakaloo_flutter_app/features/auth/domain/usecases/refresh_token_usecase.dart';
import 'package:bakaloo_flutter_app/features/auth/domain/usecases/send_otp_usecase.dart';
import 'package:bakaloo_flutter_app/features/auth/domain/usecases/verify_otp_usecase.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';

part 'auth_notifier.g.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((Ref ref) {
  return AuthRemoteDataSource(ref.watch(apiClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((Ref ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    secureStorageService: ref.watch(secureStorageProvider),
  );
});

final sendOtpUseCaseProvider = Provider<SendOtpUseCase>((Ref ref) {
  return SendOtpUseCase(ref.watch(authRepositoryProvider));
});

final verifyOtpUseCaseProvider = Provider<VerifyOtpUseCase>((Ref ref) {
  return VerifyOtpUseCase(ref.watch(authRepositoryProvider));
});

final refreshTokenUseCaseProvider = Provider<RefreshTokenUseCase>((Ref ref) {
  return RefreshTokenUseCase(ref.watch(authRepositoryProvider));
});

final logoutUseCaseProvider = Provider<LogoutUseCase>((Ref ref) {
  return LogoutUseCase(ref.watch(authRepositoryProvider));
});

const authNotifierProvider = authProvider;
const authStateProvider = authNotifierProvider;

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() {
    ref.onDispose(() {
      ref.read(socketServiceProvider).disconnect();
    });
    return const AuthUnauthenticated();
  }

  Future<void> sendOtp(String phone) async {
    state = const AuthLoading();

    final result = await ref.read(sendOtpUseCaseProvider).call(phone);
    result.fold(
      (failure) => state = AuthError(message: failure.message),
      (_) => state = AuthOtpSent(phone: phone),
    );
  }

  Future<void> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    state = const AuthLoading();

    final result = await ref.read(verifyOtpUseCaseProvider).call(
          phone: phone,
          otp: otp,
        );

    await result.fold<Future<void>>(
      (failure) async {
        state = AuthError(message: failure.message);
      },
      (authEntity) async {
        ref.read(socketServiceProvider).connect(authEntity.accessToken);
        await _registerFcmToken();

        // PHASE 6 FIX: Reconcile per-user cache BEFORE marking authenticated.
        // If a different user (e.g. demo → real) logged in, their cart/wallet/
        // order snapshots are wiped so stale data never renders.
        await AppCacheManager.reconcileUser(authEntity.user.id);

        // Invalidate user-scoped providers so they refetch for THIS user.
        _invalidateUserScopedProviders();

        state = AuthAuthenticated(user: authEntity.user);
        await _importGuestLocationIfNeeded();
        unawaited(_triggerAllocationAutoAssign());
      },
    );
  }

  Future<bool> refreshSession(String refreshToken) async {
    final result = await ref.read(refreshTokenUseCaseProvider).call(
          refreshToken,
        );

    return result.fold<Future<bool>>(
      (failure) async {
        // PHASE 5 FIX (mobile-network stale-UI / forced-logout bug):
        // Only force the user back to login when the refresh genuinely
        // FAILED authentication (expired/invalid refresh token → AuthFailure).
        // A NetworkFailure (mobile-data timeout, tunnel hiccup, no route to
        // host) must NOT log the user out — that was a major cause of the
        // "I switched to mobile data and got logged out / saw the old login
        // screen" report. In that case we keep the existing session alive
        // optimistically using the still-valid cached identity; the next
        // successful request (or the 401 refresh interceptor) will reconcile.
        if (failure is NetworkFailure || failure is ServerFailure) {
          final cachedUser = HiveService.userBox.get('user');
          final user = _userFromCache(cachedUser);
          if (user != null) {
            // Keep the session visible. Do NOT connect the socket here — the
            // access token is stale; the socket will (re)connect once a fresh
            // token is obtained by the refresh interceptor on the next call.
            state = AuthAuthenticated(user: user);
            return true;
          }
          // No cached identity to fall back on — stay unauthenticated but do
          // NOT clear tokens, so a later retry can still refresh.
          state = const AuthUnauthenticated();
          return false;
        }

        // Genuine auth failure — the refresh token is no longer valid.
        state = const AuthUnauthenticated();
        return false;
      },
      (tokenEntity) async {
        await restoreSession(tokenEntity.accessToken);
        return true;
      },
    );
  }

  Future<void> restoreSession(String accessToken) async {
    final cachedUser = HiveService.userBox.get('user');
    final user = _userFromCache(cachedUser) ??
        _userFromClaims(JwtDecoder.decode(accessToken));

    // PHASE 6 FIX: Reconcile per-user cache on session restore too, so a
    // reinstall/update that restored a token for a different user can't show
    // the previous user's cached data.
    await AppCacheManager.reconcileUser(user.id);

    state = AuthAuthenticated(user: user);
    ref.read(socketServiceProvider).connect(accessToken);

    await _importGuestLocationIfNeeded();

    // FIX: Also trigger auto-assign on session restore so that a user
    // who last opened the app before the fix now gets allocation resolved.
    unawaited(_triggerAllocationAutoAssign());
  }

  /// Keeps the persisted + in-memory auth user in sync after a profile
  /// edit (name/email/birthday saved via ProfileNotifier.updateProfile).
  ///
  /// Without this, a saved name "reverts" the next time the app is closed
  /// and reopened: HiveService.userBox is only ever written once, at
  /// login (auth_repository_impl.dart), and restoreSession() rebuilds
  /// AuthAuthenticated from that same stale cache on every cold start —
  /// so anything ProfileNotifier saved to the backend was never reflected
  /// back into the identity this app actually reads from on relaunch.
  Future<void> syncCachedUser(UserEntity updated) async {
    if (state case AuthAuthenticated()) {
      state = AuthAuthenticated(user: updated);
    }
    await HiveService.userBox.put(
      'user',
      UserModel(
        id: updated.id,
        phone: updated.phone,
        role: updated.role,
        name: updated.name,
        email: updated.email,
        avatarUrl: updated.avatarUrl,
        loyaltyPoints: updated.loyaltyPoints,
        referralCode: updated.referralCode,
      ).toJson(),
    );
  }

  Future<void> logout() async {
    // Only hit the network logout endpoint if there's actually a session to
    // invalidate. Without this guard, every 401 from an anonymous session
    // (e.g. hitting /wallet with no token) routes through
    // RefreshInterceptor's force-logout path and fires a real POST
    // /auth/logout — for a user who was never logged in. With several
    // auth-gated requests in flight on a cold home load, that cascades into
    // dozens of logout calls and trips the server's rate limiter.
    if (state is AuthAuthenticated) {
      await ref.read(logoutUseCaseProvider).call();
    }
    await ref.read(secureStorageProvider).clearAll();
    await HiveService.userBox.clear();
    await HiveService.settingsBox.delete(StorageKeys.lastFcmToken);
    // PHASE 6 FIX: Clear the current user's scoped caches on logout so the
    // next user (or the same user re-logging in) never sees stale cart/wallet.
    await AppCacheManager.reconcileUser('');
    // Reset the shop scope to anonymous so a subsequent anonymous session
    // (or a different customer logging in on this device) reads/writes the
    // 'anon' cache namespace rather than this customer's resolved shop scope.
    await AppCacheManager.resetShopScope();
    ref.read(socketServiceProvider).disconnect();
    state = const AuthUnauthenticated();
  }

  /// Invalidate user-scoped Riverpod providers so they refetch fresh data for
  /// the newly authenticated user instead of serving the previous session's
  /// in-memory state. Best-effort — a missing provider never blocks login.
  ///
  /// Storefront content (theme, tabs, sections, banners, products) is NOT
  /// listed here on purpose: it is keyed by `StorefrontScope`, so when the
  /// customer's shop allocation resolves to a different shop the scope changes
  /// and every storefront provider rebuilds for it automatically — there is no
  /// hand-maintained invalidation list to fall out of date.
  void _invalidateUserScopedProviders() {
    try {
      ref.invalidate(cartProvider);
    } catch (_) {}
    try {
      ref.invalidate(walletProvider);
    } catch (_) {}
  }

  UserEntity? _userFromCache(dynamic cachedUser) {
    if (cachedUser is! Map) {
      return null;
    }

    try {
      return UserModel.fromJson(
        Map<String, dynamic>.from(cachedUser),
      ).toEntity();
    } catch (_) {
      return null;
    }
  }

  UserEntity _userFromClaims(Map<String, dynamic> claims) {
    return UserEntity(
      id: _stringValue(claims, <String>['id', 'userId', 'sub']),
      phone: _stringValue(claims, <String>['phone']),
      name: _nullableValue(claims, <String>['name']),
      email: _nullableValue(claims, <String>['email']),
      avatarUrl: _nullableValue(claims, <String>['avatarUrl', 'avatar_url']),
      role: _stringValue(claims, <String>['role'], fallback: 'CUSTOMER'),
      loyaltyPoints:
          _intValue(claims, <String>['loyaltyPoints', 'loyalty_points']),
      referralCode:
          _nullableValue(claims, <String>['referralCode', 'referral_code']),
    );
  }

  String _stringValue(
    Map<String, dynamic> source,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    return fallback;
  }

  String? _nullableValue(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  int? _intValue(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
    }
    return null;
  }

  /// FIX: After login or session restore, call POST /allocation/auto-assign
  /// to ensure the user has a shop allocation if they have a default address.
  /// This resolves the "Product not found" error for real users who logged in
  /// but never had allocation triggered.
  ///
  /// Fire-and-forget — auth state is already set before this runs.
  /// If it fails, the home stays empty until an allocation is resolved. This
  /// deliberately prevents a customer from seeing another shop's catalogue.
  Future<void> _triggerAllocationAutoAssign() async {
    try {
      // Dio's BaseOptions set contentType: 'application/json' globally, so a
      // call with no `data:` still sends that header with a zero-length body
      // — Fastify's default JSON body parser rejects that combination with
      // 400 FST_ERR_CTP_EMPTY_JSON_BODY before this route's handler ever
      // runs. An explicit empty object avoids that; see
      // order_remote_datasource.dart's reorder() for the same pattern.
      final response = await ref.read(dioClientProvider).post<dynamic>(
        ApiConstants.allocationAutoAssign,
        data: <String, dynamic>{},
      );
      // Committing the resolved shop scope is the whole job: every storefront
      // provider watches it, so a changed allocation re-keys and reloads the
      // theme, sections, banners and products together (see
      // _invalidateUserScopedProviders' doc).
      await AppCacheManager.applyAllocationResponse(response.data);
    } on DioException catch (e) {
      // 401 means token expired — ignore; the refresh interceptor will handle it.
      // Any other error is non-fatal: the anonymous fallback keeps products visible.
      if (e.response?.statusCode != 401) {
        // Silent — do not block auth or show error to user.
      }
    } catch (_) {
      // Non-fatal — ignore.
    }
  }

  /// A guest location is encrypted local device state, never a backend guest
  /// record. Once that guest signs in, promote it to a real delivery address
  /// only when this account has no address at all; existing accounts keep
  /// their own selected/default address untouched.
  Future<void> _importGuestLocationIfNeeded() async {
    try {
      final raw =
          HiveService.settingsBox.get(StorageKeys.guestStorefrontLocation);
      if (raw is! Map) return;
      final pincode = raw['pincode'] as String?;
      final lat = raw['lat'] as num?;
      final lng = raw['lng'] as num?;
      if (pincode == null || pincode.isEmpty || lat == null || lng == null)
        return;

      final dio = ref.read(dioClientProvider);
      final existingResponse = await dio.get<dynamic>(ApiConstants.addresses);
      final payload = existingResponse.data;
      final data = payload is Map ? payload['data'] : null;
      if (data is List && data.isNotEmpty) return;

      await dio.post<dynamic>(ApiConstants.addresses, data: {
        'label': 'Home',
        'addressLine1':
            (raw['addressLine1'] as String?)?.trim().isNotEmpty == true
                ? raw['addressLine1']
                : 'My Location',
        'city': (raw['city'] as String?)?.trim().isNotEmpty == true
            ? raw['city']
            : 'Local Area',
        'state': raw['state'] ?? '',
        'pincode': pincode,
        'lat': lat.toDouble(),
        'lng': lng.toDouble(),
        'isDefault': true,
      });
      ref.invalidate(addressProvider);
    } catch (_) {
      // Login succeeds even if the network fails. The guest location stays
      // local and a later authenticated app open retries the normal flow.
    }
  }

  Future<void> _registerFcmToken() async {
    // Browser push requires Firebase Web credentials, VAPID configuration and
    // a messaging service worker. Until those are supplied, login must not
    // attempt the native FCM registration path.
    if (kIsWeb) return;
    try {
      final token = await getFcmTokenAwaitingApns(FirebaseMessaging.instance);
      if (token == null || token.isEmpty) {
        return;
      }

      final lastToken = HiveService.settingsBox.get(
        StorageKeys.lastFcmToken,
      ) as String?;
      if (lastToken == token) {
        return;
      }

      await ref.read(dioClientProvider).post<dynamic>(
        ApiConstants.notificationTokens,
        data: <String, dynamic>{
          'token': token,
          'platform': _platformName,
        },
      );

      await HiveService.settingsBox.put(StorageKeys.lastFcmToken, token);
    } on DioException catch (err, stack) {
      // FCM registration must not block authentication success — but a
      // silent failure here previously left no trace anywhere (the iOS
      // "no notifications at all" bug was invisible until traced through
      // the code). Record it non-fatally instead of swallowing it outright.
      unawaited(
        reportError(
          err,
          stack,
          reason: 'FCM token registration failed (network)',
          fatal: false,
        ),
      );
    } catch (err, stack) {
      unawaited(
        reportError(
          err,
          stack,
          reason: 'FCM token registration failed',
          fatal: false,
        ),
      );
    }
  }

  String get _platformName {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }
}
