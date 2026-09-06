import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/security/root_detection.dart';
import 'package:bakaloo_flutter_app/core/session/session_ready_gate.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

part 'splash_provider.g.dart';

@Riverpod(keepAlive: true)
class SplashController extends _$SplashController {
  @override
  void build() {}

  Future<void> handleStartup(BuildContext context) async {
    final blocked = await RootDetection.blockIfCompromised(context);
    if (blocked) {
      return;
    }

    // Everything below decides the real AuthState. Notification taps wait
    // on SessionReadyGate before navigating, so this MUST flip to "ready"
    // no matter which branch below returns (or throws) — otherwise a
    // notification tap during startup would wait forever.
    try {
      // Minimum time the splash logo stays visible so it doesn't just flash
      // by — NOT a loading wait. Session restore below reads from local
      // storage/cache and is typically faster than this on its own; keeping
      // this short (rather than the old fixed 2200ms) means the delay is
      // barely noticeable instead of adding real dead time to every launch.
      await Future<void>.delayed(const Duration(milliseconds: 400));

      final secureStorage = ref.read(secureStorageProvider);
      final accessToken = await secureStorage.getAccessToken();
      final refreshToken = await secureStorage.getRefreshToken();

      if (!context.mounted) {
        return;
      }

      if (accessToken == null || refreshToken == null) {
        context.go(RouteNames.home);
        return;
      }

      if (!JwtDecoder.isExpired(accessToken)) {
        await ref
            .read(authNotifierProvider.notifier)
            .restoreSession(accessToken);
        if (context.mounted) {
          context.go(RouteNames.home);
        }
        return;
      }

      await ref.read(authNotifierProvider.notifier).refreshSession(
            refreshToken,
          );

      if (!context.mounted) {
        return;
      }

      context.go(RouteNames.home);
    } finally {
      ref.read(sessionReadyGateProvider).markReady();
    }
  }
}
