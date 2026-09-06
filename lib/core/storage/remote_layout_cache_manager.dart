import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';

/// Current schema version for remote layout caches.
///
/// Increment this value whenever a deployment changes the remote theme/section
/// manifest format in a way that would cause old cached payloads to produce
/// wrong or stale UI (e.g. new seasonal campaign, changed section types,
/// updated tab structure).
///
/// On app start [RemoteLayoutCacheManager.ensureCurrentVersion] checks the
/// stored version against this constant. A mismatch wipes all remote layout
/// keys while preserving auth/user/cart data.
const int remoteLayoutCacheVersion = 2;

/// Box and key names used by the section manifest provider (not in StorageKeys
/// because the section manifest provider manages its own box).
const String _sectionManifestBoxName = 'section_manifests';

/// Keys inside [HiveService.remoteThemeBox] that belong to old deployments
/// and can be wiped safely on a version bump.
const List<String> _legacyRemoteThemeKeys = <String>[
  'tab_themes_data', // old unversioned zepto key
  'data', // legacy single-theme key
];

const String _cacheVersionKey = 'bakaloo_remote_layout_cache_version';

class RemoteLayoutCacheManager {
  RemoteLayoutCacheManager._();

  /// Must be called once after [HiveService.init] and before the home screen
  /// renders. Safe to call on every cold start — it is a no-op when the stored
  /// version matches [remoteLayoutCacheVersion].
  static Future<void> ensureCurrentVersion() async {
    try {
      final dynamic storedRaw =
          HiveService.settingsBox.get(_cacheVersionKey);
      final int storedVersion =
          storedRaw is int ? storedRaw : int.tryParse('$storedRaw') ?? 0;

      if (storedVersion == remoteLayoutCacheVersion) {
        return; // Up to date — nothing to do.
      }

      debugPrint(
        '[CacheManager] Remote layout cache version mismatch '
        '(stored=$storedVersion current=$remoteLayoutCacheVersion). '
        'Clearing stale remote layout caches…',
      );

      await _clearRemoteLayoutCaches();
      await HiveService.settingsBox
          .put(_cacheVersionKey, remoteLayoutCacheVersion);

      debugPrint('[CacheManager] Remote layout caches cleared.');
    } catch (error) {
      debugPrint('[CacheManager] ensureCurrentVersion failed: $error');
    }
  }

  /// Wipes all remote layout caches without touching auth/user/cart data.
  static Future<void> _clearRemoteLayoutCaches() async {
    await _clearRemoteThemeBox();
    await _clearSectionManifestBox();
  }

  static Future<void> _clearRemoteThemeBox() async {
    try {
      final box = HiveService.remoteThemeBox;

      // Collect all keys that are versioned remote-theme entries
      // (pattern: tab_themes_data_<storeKey> or tab_home_data_<storeKey>_<tabKey>).
      final keysToDelete = box.keys
          .whereType<String>()
          .where(
            (key) =>
                key.startsWith('tab_themes_data_') ||
                key.startsWith('tab_home_data_') ||
                _legacyRemoteThemeKeys.contains(key),
          )
          .toList(growable: false);

      await box.deleteAll(keysToDelete);
      debugPrint(
        '[CacheManager] remoteThemeBox: deleted ${keysToDelete.length} keys.',
      );
    } catch (error) {
      debugPrint('[CacheManager] remoteThemeBox clear failed: $error');
    }
  }

  static Future<void> _clearSectionManifestBox() async {
    try {
      if (!Hive.isBoxOpen(_sectionManifestBoxName)) {
        // Open it just to wipe, then close.
        final box =
            await Hive.openBox<dynamic>(_sectionManifestBoxName);
        await box.clear();
        await box.close();
      } else {
        await Hive.box<dynamic>(_sectionManifestBoxName).clear();
      }
      debugPrint('[CacheManager] sectionManifestBox: cleared.');
    } catch (error) {
      debugPrint('[CacheManager] sectionManifestBox clear failed: $error');
    }
  }
}
