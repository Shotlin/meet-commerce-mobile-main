import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/core/storage/remote_layout_cache_manager.dart';
import 'package:bakaloo_flutter_app/core/storage/secure_storage_service.dart';

/// PHASE 1 (mobile-network stale-UI bug): startup self-diagnostics.
///
/// Prints a single, compact block at cold start describing exactly which
/// build / backend / network / auth / cache state the app booted into. This
/// is the fastest way to confirm in the field whether a "stale old UI" report
/// is caused by an old build, a wrong API URL, a stale cache version, or a
/// network type — without attaching a debugger.
///
/// Runs ONLY in debug and profile builds. In release builds the whole method
/// is a no-op (guarded by [kReleaseMode]) so it adds zero overhead and leaks
/// no diagnostics to end users.
class StartupDiagnostics {
  StartupDiagnostics._();

  static Future<void> log() async {
    if (kReleaseMode) {
      return; // No diagnostics in release builds.
    }

    try {
      const buildMode = kDebugMode
          ? 'debug'
          : (kProfileMode ? 'profile' : 'release');

      String appVersion = 'unknown';
      try {
        final info = await PackageInfo.fromPlatform();
        appVersion = '${info.version}+${info.buildNumber}';
      } catch (_) {
        // package_info unavailable in some test contexts — ignore.
      }

      String networkType = 'unknown';
      try {
        final results = await Connectivity().checkConnectivity();
        networkType = _describeConnectivity(results);
      } catch (_) {
        // ignore
      }

      bool hasAccessToken = false;
      bool hasRefreshToken = false;
      try {
        final storage = SecureStorageService();
        hasAccessToken = (await storage.getAccessToken())?.isNotEmpty ?? false;
        hasRefreshToken = (await storage.getRefreshToken())?.isNotEmpty ?? false;
      } catch (_) {
        // ignore
      }

      final cachedUser = HiveService.userBox.get('user');
      final hasCachedUser = cachedUser is Map && cachedUser.isNotEmpty;

      final storedSchema =
          HiveService.settingsBox.get('bakaloo_app_cache_schema_version');
      final storedBaseUrl =
          HiveService.settingsBox.get('bakaloo_app_cache_api_base_url');

      debugPrint(
        '\n══════════ BAKALOO STARTUP DIAGNOSTICS ══════════\n'
        '  build mode      : $buildMode\n'
        '  app version     : $appVersion\n'
        '  API base URL    : ${ApiConstants.baseUrl}\n'
        '  socket URL      : ${ApiConstants.socketUrl}\n'
        '  network type    : $networkType\n'
        '  auth state      : '
        '${hasAccessToken ? 'access✓' : 'access✗'} '
        '${hasRefreshToken ? 'refresh✓' : 'refresh✗'} '
        '${hasCachedUser ? 'cachedUser✓' : 'cachedUser✗'}\n'
        '  app cache ver   : current=${AppCacheManager.appCacheSchemaVersion} '
        'stored=$storedSchema\n'
        '  layout cache ver: current=$remoteLayoutCacheVersion\n'
        '  cache base URL  : stored=$storedBaseUrl\n'
        '  render path     : '
        '${hasAccessToken || hasCachedUser ? 'restore-session → /home' : 'anonymous → /home'}\n'
        '═════════════════════════════════════════════════\n',
      );
    } catch (error) {
      debugPrint('[StartupDiagnostics] failed: $error');
    }
  }

  static String _describeConnectivity(List<ConnectivityResult> results) {
    if (results.isEmpty ||
        results.every((r) => r == ConnectivityResult.none)) {
      return 'offline';
    }
    return results
        .where((r) => r != ConnectivityResult.none)
        .map((r) => r.name)
        .join(',');
  }
}
