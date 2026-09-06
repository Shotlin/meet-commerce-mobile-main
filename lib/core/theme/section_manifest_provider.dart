import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/providers/store_provider.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_service.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_model.dart';
import 'package:bakaloo_flutter_app/core/theme/theme_asset_warmer.dart';

const String _sectionManifestBoxName = 'section_manifests';

final Map<String, SectionManifestResponse> _memoryCache =
    <String, SectionManifestResponse>{};
final Map<String, String> _etagCache = <String, String>{};

class _SectionManifestEpochNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final _sectionManifestEpochProvider =
    NotifierProvider<_SectionManifestEpochNotifier, int>(
  _SectionManifestEpochNotifier.new,
);

final activeTabKeyProvider = Provider<String>((Ref ref) {
  final String selectedTabKey = ref.watch(selectedCategoryIdProvider);
  final TabThemesResponse? snapshot = ref.watch(tabThemesSnapshotProvider);
  final AsyncValue<TabThemesResponse> tabThemes = ref.watch(tabThemesProvider);
  final TabThemesResponse? response = snapshot ?? tabThemes.asData?.value;

  if (response != null && response.tabMap.containsKey(selectedTabKey)) {
    return selectedTabKey;
  }

  return response?.defaultTabEntry?.tabKey ??
      (selectedTabKey.isEmpty ? 'all' : selectedTabKey);
});

final socketSectionUpdateStreamProvider =
    StreamProvider<Map<String, dynamic>>((Ref ref) {
  return ref.watch(socketServiceProvider).sectionUpdateStream;
});

final sectionManifestProvider =
    FutureProvider.family<SectionManifestResponse, String>(
  (Ref ref, String tabKey) async {
    ref.watch(_sectionManifestEpochProvider);
    final String storeKey = ref.watch(selectedStoreProvider).id;
    final String cacheKey = _cacheKey(storeKey, tabKey);

    final SectionManifestResponse? memory = _memoryCache[cacheKey];
    if (memory != null) {
      unawaited(ThemeAssetWarmer.warmSectionManifest(memory));
      unawaited(_fetchAndCacheSectionManifest(ref, storeKey, tabKey));
      return memory;
    }

    try {
      final Box<dynamic> box = await _openSectionManifestBox();
      final dynamic cached = box.get(_manifestCacheKey(storeKey, tabKey));
      final Map<String, dynamic> cachedMap = _decodeToMap(cached);
      if (cachedMap.isNotEmpty) {
        final SectionManifestResponse cachedResponse =
            SectionManifestResponse.fromJson(cachedMap);
        _memoryCache[cacheKey] = cachedResponse;
        final String? etag = cachedResponse.etag;
        if (etag != null && etag.isNotEmpty) {
          _etagCache[cacheKey] = etag;
        }
        unawaited(ThemeAssetWarmer.warmSectionManifest(cachedResponse));
        unawaited(_fetchAndCacheSectionManifest(ref, storeKey, tabKey));
        return cachedResponse;
      }
    } catch (error) {
      debugPrint('[Sections][$storeKey/$tabKey] Hive read failed: $error');
    }

    return await _fetchAndCacheSectionManifest(ref, storeKey, tabKey) ??
        _memoryCache[cacheKey] ??
        SectionManifestResponse(
          tabKey: tabKey,
          storeKey: storeKey,
          sections: const <SectionManifestEntry>[],
        );
  },
);

final activeSectionManifestProvider = Provider<SectionManifestResponse>(
  (Ref ref) {
    final String activeTabKey = ref.watch(activeTabKeyProvider);
    final String storeKey = ref.watch(selectedStoreProvider).id;
    final AsyncValue<SectionManifestResponse> manifest = ref.watch(
      sectionManifestProvider(activeTabKey),
    );

    return manifest.asData?.value ??
        _memoryCache[_cacheKey(storeKey, activeTabKey)] ??
        SectionManifestResponse.empty;
  },
);

Future<void> handleSectionSocketEvent(WidgetRef ref, Map data) async {
  final String? tabKey = _parseNullableString(data['tab_key']);
  if (tabKey == null || tabKey.isEmpty) {
    return;
  }

  await refreshSectionManifest(ref, tabKey);
}

Future<void> refreshSectionManifest(WidgetRef ref, String tabKey) async {
  final String storeKey = ref.read(selectedStoreProvider).id;

  final List<String> keysToRemove = _memoryCache.keys
      .where((String key) => key.endsWith('::$tabKey'))
      .toList(growable: false);

  for (final String key in keysToRemove) {
    _memoryCache.remove(key);
    _etagCache.remove(key);
  }

  try {
    final Box<dynamic> box = await _openSectionManifestBox();
    await box.delete(_manifestCacheKey(storeKey, tabKey));
  } catch (error) {
    debugPrint(
      '[Sections][$storeKey/$tabKey] Cache clear failed before refresh: $error',
    );
  }

  ref
    ..invalidate(sectionManifestProvider(tabKey))
    ..invalidate(activeSectionManifestProvider);

  await ref.read(sectionManifestProvider(tabKey).future);
}

Future<SectionManifestResponse?> _fetchAndCacheSectionManifest(
  Ref ref,
  String storeKey,
  String tabKey,
) async {
  final String cacheKey = _cacheKey(storeKey, tabKey);

  try {
    final Dio dio = _buildDio();
    final Map<String, dynamic> headers = <String, dynamic>{};
    final String? etag = _etagCache[cacheKey] ?? _memoryCache[cacheKey]?.etag;
    if (etag != null && etag.isNotEmpty) {
      headers['If-None-Match'] = etag;
    }

    final Response<dynamic> response = await dio.get<dynamic>(
      '${ApiConstants.sectionManifest}/$tabKey/sections',
      queryParameters: <String, dynamic>{'store_key': storeKey},
      options: Options(
        headers: headers,
        validateStatus: (int? status) => status != null && status < 500,
      ),
    );

    if (response.statusCode == 304) {
      return _readCachedSectionManifestSnapshot(storeKey, tabKey);
    }

    final dynamic payload = response.data;
    if (payload is! Map) {
      return _readCachedSectionManifestSnapshot(storeKey, tabKey);
    }

    final Map<String, dynamic> body = Map<String, dynamic>.from(payload);
    if (body['success'] != true || body['data'] is! Map) {
      return _readCachedSectionManifestSnapshot(storeKey, tabKey);
    }

    final Map<String, dynamic> dataMap =
        Map<String, dynamic>.from(body['data'] as Map<dynamic, dynamic>);
    final String? responseEtag = response.headers.value('etag');
    if (responseEtag != null && responseEtag.isNotEmpty) {
      dataMap['etag'] = responseEtag;
    }

    final Box<dynamic> box = await _openSectionManifestBox();
    final String manifestCacheKey = _manifestCacheKey(storeKey, tabKey);
    final String encodedData = jsonEncode(dataMap);
    final dynamic cachedRaw = box.get(manifestCacheKey);
    final String? cachedEncoded = cachedRaw is String
        ? cachedRaw
        : cachedRaw is Map
            ? jsonEncode(cachedRaw)
            : null;

    await box.put(manifestCacheKey, encodedData);
    await HiveService.markCached('cache_section_manifest_${storeKey}_$tabKey');

    final SectionManifestResponse parsed =
        SectionManifestResponse.fromJson(dataMap);
    _memoryCache[cacheKey] = parsed;
    unawaited(ThemeAssetWarmer.warmSectionManifest(parsed));

    if (parsed.etag != null && parsed.etag!.isNotEmpty) {
      _etagCache[cacheKey] = parsed.etag!;
    } else {
      _etagCache.remove(cacheKey);
    }

    if (cachedEncoded != encodedData) {
      ref.read(_sectionManifestEpochProvider.notifier).bump();
    }

    return parsed;
  } catch (error) {
    debugPrint(
      '[Sections][$storeKey/$tabKey] API fetch failed (using cache): $error',
    );
    return _readCachedSectionManifestSnapshot(storeKey, tabKey) ??
        SectionManifestResponse(
          tabKey: tabKey,
          storeKey: storeKey,
          sections: const <SectionManifestEntry>[],
        );
  }
}

SectionManifestResponse? _readCachedSectionManifestSnapshot(
  String storeKey,
  String tabKey,
) {
  final String cacheKey = _cacheKey(storeKey, tabKey);
  final SectionManifestResponse? memory = _memoryCache[cacheKey];
  if (memory != null) {
    return memory;
  }

  try {
    if (!Hive.isBoxOpen(_sectionManifestBoxName)) {
      return null;
    }

    final Box<dynamic> box = Hive.box<dynamic>(_sectionManifestBoxName);
    final dynamic cached = box.get(_manifestCacheKey(storeKey, tabKey));
    final Map<String, dynamic> cachedMap = _decodeToMap(cached);
    if (cachedMap.isEmpty) {
      return null;
    }

    final SectionManifestResponse response =
        SectionManifestResponse.fromJson(cachedMap);
    _memoryCache[cacheKey] = response;
    final String? etag = response.etag;
    if (etag != null && etag.isNotEmpty) {
      _etagCache[cacheKey] = etag;
    }
    return response;
  } catch (error) {
    debugPrint('[Sections][$storeKey/$tabKey] Snapshot read failed: $error');
    return null;
  }
}

Future<Box<dynamic>> _openSectionManifestBox() async {
  if (Hive.isBoxOpen(_sectionManifestBoxName)) {
    return Hive.box<dynamic>(_sectionManifestBoxName);
  }
  return Hive.openBox<dynamic>(_sectionManifestBoxName);
}

Dio _buildDio() {
  return Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      // Use the same generous timeout as the main DioClient so the emulator's
      // NAT-based connection to the Cloudflare tunnel doesn't time out before
      // the section manifest is returned (previously 5s — too aggressive for
      // mobile-data / tunnel latency).
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 40),
    ),
  );
}

Map<String, dynamic> _decodeToMap(dynamic cached) {
  if (cached is String) {
    final dynamic decoded = jsonDecode(cached);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{};
  }

  if (cached is Map<String, dynamic>) {
    return cached;
  }
  if (cached is Map) {
    return Map<String, dynamic>.from(cached);
  }
  return <String, dynamic>{};
}

String _cacheKey(String storeKey, String tabKey) => '$storeKey::$tabKey';

String _manifestCacheKey(String storeKey, String tabKey) =>
    'section_manifest_${storeKey}_$tabKey';

String? _parseNullableString(dynamic value) {
  if (value == null) {
    return null;
  }

  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}
