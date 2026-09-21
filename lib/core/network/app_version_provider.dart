import 'dart:io';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';

part 'app_version_provider.g.dart';

enum AppUpdateSeverity { none, soft, force }

class AppVersionCheckResult {
  const AppVersionCheckResult({
    required this.severity,
    this.latestVersionName,
    this.updateMessage,
    this.storeUrl,
  });

  static const AppVersionCheckResult none = AppVersionCheckResult(
    severity: AppUpdateSeverity.none,
  );

  final AppUpdateSeverity severity;
  final String? latestVersionName;
  final String? updateMessage;
  final String? storeUrl;

  /// A force-update verdict is only actionable if there's actually a store
  /// link to send the customer to — an admin who raises the minimum
  /// supported build before filling in the store URL must never trap
  /// customers behind an unrecoverable full-screen blocker with no way out.
  bool get canForceUpdate =>
      severity == AppUpdateSeverity.force &&
      (storeUrl?.trim().isNotEmpty ?? false);
}

/// Checked once per app launch, entirely independent of auth state and of
/// [dioClientProvider]'s shared interceptor chain (availability monitoring,
/// auth-refresh, etc.) — a bare, short-timeout client so a slow/unreachable
/// backend can never affect anything else in the app, and always fails open
/// (returns [AppVersionCheckResult.none]) rather than blocking the app on a
/// network hiccup.
@riverpod
Future<AppVersionCheckResult> appVersionCheck(Ref ref) async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final buildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
    if (buildNumber <= 0) {
      return AppVersionCheckResult.none;
    }

    final platform = Platform.isIOS ? 'ios' : 'android';
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );

    final response = await dio.get<dynamic>(
      ApiConstants.appVersionCheck,
      queryParameters: <String, dynamic>{
        'platform': platform,
        'buildNumber': buildNumber,
      },
    );

    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)['data']
        : null;
    if (data is! Map) {
      return AppVersionCheckResult.none;
    }
    final payload = Map<String, dynamic>.from(data);

    final forceUpdate = payload['forceUpdate'] == true;
    final softUpdate = payload['softUpdate'] == true;

    return AppVersionCheckResult(
      severity: forceUpdate
          ? AppUpdateSeverity.force
          : softUpdate
              ? AppUpdateSeverity.soft
              : AppUpdateSeverity.none,
      latestVersionName: payload['latestVersionName'] as String?,
      updateMessage: payload['updateMessage'] as String?,
      storeUrl: payload['storeUrl'] as String?,
    );
  } catch (_) {
    // Fail open — a network hiccup, backend blip, or unexpected response
    // shape must never block (or even slow down) app startup.
    return AppVersionCheckResult.none;
  }
}
