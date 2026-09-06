import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';

/// Single source of truth for app-wide cache invalidation policy.
///
/// PHASE 2 FIX (mobile-network stale-UI bug):
///   The previous code only versioned the *remote layout* cache. Theme,
///   product, category, banner, wallet and cart snapshot caches could all
///   survive an app update or a user switch and render old/stale UI when a
///   mobile-data request timed out and the app fell back to cache.
///
/// This manager enforces three rules on every cold start:
///   1. APP_CACHE_SCHEMA_VERSION bump → wipe ALL non-auth caches.
///   2. API base URL change (e.g. staging → prod) → wipe ALL non-auth caches
///      so a cache built against a different backend can never render.
///   3. Logged-in user change → wipe user-specific caches (cart/wallet/orders)
///      so demo-user data never leaks into a real user's session and vice
///      versa.
///
/// Auth tokens (secure storage) and the encrypted user box are never touched
/// here — session continuity is preserved.
class AppCacheManager {
  AppCacheManager._();

  /// Bump this whenever ANY cached payload schema changes in a way that would
  /// render stale/wrong UI from an older build.
  static const int appCacheSchemaVersion = 3;

  static const String _schemaVersionKey = 'bakaloo_app_cache_schema_version';
  static const String _apiBaseUrlKey = 'bakaloo_app_cache_api_base_url';
  static const String _lastUserIdKey = 'bakaloo_app_cache_last_user_id';

  static const String _sectionManifestBoxName = 'section_manifests';

  /// Call once after [HiveService.init], before the first screen renders.
  /// Wipes stale caches when the schema version or API base URL changed.
  static Future<void> ensureFreshOnStartup() async {
    try {
      final settings = HiveService.settingsBox;

      final storedVersionRaw = settings.get(_schemaVersionKey);
      final storedVersion = storedVersionRaw is int
          ? storedVersionRaw
          : int.tryParse('$storedVersionRaw') ?? 0;

      final storedBaseUrl = settings.get(_apiBaseUrlKey) as String?;
      final currentBaseUrl = ApiConstants.baseUrl;

      final versionChanged = storedVersion != appCacheSchemaVersion;
      final baseUrlChanged =
          storedBaseUrl != null && storedBaseUrl != currentBaseUrl;

      if (versionChanged || baseUrlChanged) {
        debugPrint(
          '[AppCacheManager] Cache reset — '
          'versionChanged=$versionChanged (stored=$storedVersion '
          'current=$appCacheSchemaVersion) '
          'baseUrlChanged=$baseUrlChanged (stored=$storedBaseUrl '
          'current=$currentBaseUrl)',
        );
        await _clearAllNonAuthCaches();
      }

      await settings.put(_schemaVersionKey, appCacheSchemaVersion);
      await settings.put(_apiBaseUrlKey, currentBaseUrl);
    } catch (error) {
      debugPrint('[AppCacheManager] ensureFreshOnStartup failed: $error');
    }
  }

  /// Call right after a confirmed login/session restore once the user id is
  /// known. If the user changed since the last session, wipe user-specific
  /// caches (cart/wallet/orders snapshots, profile cache) so no cross-user
  /// leakage occurs (demo ↔ real user).
  static Future<void> reconcileUser(String? userId) async {
    try {
      final settings = HiveService.settingsBox;
      final storedUserId = settings.get(_lastUserIdKey) as String?;
      final normalized = (userId ?? '').trim();

      if (storedUserId != null && storedUserId != normalized) {
        debugPrint(
          '[AppCacheManager] User changed '
          '(stored=$storedUserId current=$normalized) — '
          'clearing user-specific caches.',
        );
        await _clearUserSpecificCaches();
      }

      await settings.put(_lastUserIdKey, normalized);
    } catch (error) {
      debugPrint('[AppCacheManager] reconcileUser failed: $error');
    }
  }

  /// Clears everything except auth tokens and the encrypted user box.
  static Future<void> _clearAllNonAuthCaches() async {
    await _safeClearBox(HiveService.productsBox);
    await _safeClearBox(HiveService.categoriesBox);
    await _safeClearBox(HiveService.bannersBox);
    await _safeClearBox(HiveService.ordersBox);
    await _safeClearBox(HiveService.remoteThemeBox);
    await _safeClearBox(HiveService.cacheMetaBox);
    await _clearSectionManifestBox();
    try {
      final settings = HiveService.settingsBox;
      await settings.delete(StorageKeys.cacheUserProfile);
      await settings.delete(StorageKeys.cacheAddresses);
    } catch (_) {
      // best-effort
    }
  }

  /// Clears only user-scoped data caches (cart/wallet/orders/profile/addresses).
  /// Layout/theme/product caches are public and need not be wiped here.
  static Future<void> _clearUserSpecificCaches() async {
    await _safeClearBox(HiveService.ordersBox);
    // Cart and wallet are not persisted in their own Hive box (cart lives in
    // backend Redis, wallet is fetched live), but any cached profile/address
    // snapshot and order history must be dropped so the new user starts clean.
    try {
      final settings = HiveService.settingsBox;
      // Drop only cache-meta timestamps; keep auth/onboarding flags.
      // (cacheMetaBox is cleared on version bump; here we just invalidate
      //  user-derived freshness markers so the next read refetches.)
      await settings.delete(StorageKeys.cacheUserProfile);
      await settings.delete(StorageKeys.cacheAddresses);
    } catch (_) {
      // best-effort
    }
  }

  static Future<void> _safeClearBox(Box<dynamic> box) async {
    try {
      await box.clear();
    } catch (error) {
      debugPrint('[AppCacheManager] clear box failed: $error');
    }
  }

  static Future<void> _clearSectionManifestBox() async {
    try {
      if (!Hive.isBoxOpen(_sectionManifestBoxName)) {
        final box = await Hive.openBox<dynamic>(_sectionManifestBoxName);
        await box.clear();
        await box.close();
      } else {
        await Hive.box<dynamic>(_sectionManifestBoxName).clear();
      }
    } catch (error) {
      debugPrint('[AppCacheManager] sectionManifestBox clear failed: $error');
    }
  }
}
