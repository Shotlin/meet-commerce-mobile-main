import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/core/storefront/layout_keys.dart';

/// One persisted layout payload.
///
/// Stored as a single string `v3\n<savedAtMs>\n<etag>\n<rawJson>` so reads
/// need one `jsonDecode` (of the payload) and no re-encode to detect changes.
@immutable
class StoredLayout {
  const StoredLayout({required this.raw, required this.savedAt, this.etag});

  /// The server's `data` object, JSON-encoded exactly as received.
  final String raw;
  final DateTime savedAt;
  final String? etag;

  String encode() =>
      'v3\n${savedAt.millisecondsSinceEpoch}\n${etag ?? ''}\n$raw';

  static StoredLayout? decode(dynamic value) {
    if (value is! String || !value.startsWith('v3\n')) {
      return null;
    }
    final int a = value.indexOf('\n', 3);
    if (a < 0) {
      return null;
    }
    final int b = value.indexOf('\n', a + 1);
    if (b < 0) {
      return null;
    }
    final int? savedMs = int.tryParse(value.substring(3, a));
    if (savedMs == null) {
      return null;
    }
    final String etag = value.substring(a + 1, b);
    return StoredLayout(
      raw: value.substring(b + 1),
      savedAt: DateTime.fromMillisecondsSinceEpoch(savedMs),
      etag: etag.isEmpty ? null : etag,
    );
  }
}

/// Persistent layer under the layout repository.
///
/// Every key embeds the shop scope (see [AppCacheManager.scopedKey]) so
/// entries of another shop are unreachable, and old scopes are pruned when the
/// scope changes. The scope in a key is always the one captured when the
/// request started.
class LayoutDiskStore {
  const LayoutDiskStore();

  static const String _themeBase = 'layout_theme_v3';
  static const String _sectionBase = 'layout_sections_v3';

  static String themeKeyOf(ThemeKey key) => AppCacheManager.scopedKey(
        _themeBase,
        shopScope: key.shopScope,
        extra: key.storeKey,
      );

  static String sectionKeyOf(SectionKey key) => AppCacheManager.scopedKey(
        _sectionBase,
        shopScope: key.shopScope,
        extra: '${key.storeKey}|${key.priceMode}|${key.tabKey}',
      );

  StoredLayout? readTheme(ThemeKey key) =>
      _read(() => HiveService.remoteThemeBox, themeKeyOf(key));

  StoredLayout? readSections(SectionKey key) =>
      _read(() => HiveService.sectionManifestBox, sectionKeyOf(key));

  Future<void> writeTheme(ThemeKey key, StoredLayout value) =>
      _write(() => HiveService.remoteThemeBox, themeKeyOf(key), value);

  Future<void> writeSections(SectionKey key, StoredLayout value) =>
      _write(() => HiveService.sectionManifestBox, sectionKeyOf(key), value);

  StoredLayout? _read(Box<dynamic> Function() box, String key) {
    try {
      return StoredLayout.decode(box().get(key));
    } catch (error) {
      debugPrint('[LayoutDisk] read failed for $key: $error');
      return null;
    }
  }

  Future<void> _write(
    Box<dynamic> Function() box,
    String key,
    StoredLayout value,
  ) async {
    try {
      await box().put(key, value.encode());
    } catch (error) {
      debugPrint('[LayoutDisk] write failed for $key: $error');
    }
  }
}
