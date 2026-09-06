import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/branding/branding_model.dart';
import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_service.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';

const String _brandingCacheKey = 'app_branding';

/// Splash image + header logo, dashboard-editable with a bundled-asset
/// fallback. [build] returns the last cached value synchronously (so the
/// splash screen never waits on a network call for its first frame);
/// [refresh] fetches the latest config in the background and updates both
/// the live state (so an already-open app's header picks it up) and the
/// Hive cache (so the next cold start starts from the latest value).
class BrandingNotifier extends Notifier<BrandingConfig> {
  @override
  BrandingConfig build() => _readCached();

  Future<void> refresh() async {
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final response = await dio.get<dynamic>(ApiConstants.branding);
      final payload = response.data;
      if (payload is! Map) {
        return;
      }

      final body = Map<String, dynamic>.from(payload);
      if (body['success'] != true || body['data'] is! Map) {
        return;
      }

      final dataMap = Map<String, dynamic>.from(
        body['data'] as Map<dynamic, dynamic>,
      );

      await HiveService.remoteThemeBox.put(
        _brandingCacheKey,
        jsonEncode(dataMap),
      );

      state = BrandingConfig.fromJson(dataMap);
    } catch (_) {
      // Best-effort — keep whatever was already cached/shown.
    }
  }

  BrandingConfig _readCached() {
    try {
      final dynamic cached = HiveService.remoteThemeBox.get(_brandingCacheKey);
      if (cached is String) {
        final decoded = jsonDecode(cached);
        if (decoded is Map) {
          return BrandingConfig.fromJson(Map<String, dynamic>.from(decoded));
        }
      }
    } catch (_) {
      // Fall through to defaults.
    }
    return BrandingConfig.defaults();
  }
}

final brandingProvider = NotifierProvider<BrandingNotifier, BrandingConfig>(
  BrandingNotifier.new,
);

/// Fires whenever the dashboard saves a branding change, so an already-open
/// app's header logo can update without waiting for the next cold start.
final socketBrandingUpdateStreamProvider =
    StreamProvider<Map<String, dynamic>>((Ref ref) {
  return ref.watch(socketServiceProvider).brandingUpdateStream;
});
