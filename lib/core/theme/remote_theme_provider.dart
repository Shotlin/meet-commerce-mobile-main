import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';
import 'package:bakaloo_flutter_app/core/network/app_availability_provider.dart';
import 'package:bakaloo_flutter_app/core/providers/store_provider.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_service.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/tab_home_content_model.dart';
import 'package:bakaloo_flutter_app/core/theme/theme_asset_warmer.dart';

final Map<String, TabThemesResponse> _themeMemoryCache =
    <String, TabThemesResponse>{};
final Map<String, TabHomeContentResponse> _tabHomeMemoryCache =
    <String, TabHomeContentResponse>{};
final Map<String, Future<void>> _tabThemesFetchInFlight =
    <String, Future<void>>{};
final Map<String, Future<TabHomeContentResponse?>> _tabHomeFetchInFlight =
    <String, Future<TabHomeContentResponse?>>{};
final Set<String> _tabHomePrefetchInFlight = <String>{};
final Set<String> _sectionManifestPrefetchInFlight = <String>{};

const int _tabHomePrefetchLimit = 3;

// PHASE 4A: Scroll-idle signalling.
// Updated by _HomeScreenState on every scroll event. Module-level so the
// themeRefreshTimerProvider closure can read it without coupling to the widget.
// Epoch milliseconds of the last scroll event; 0 = no scroll yet.
int homeScrollLastEventMs = 0;
// A scroll is considered "active" for 800ms after the last event.
const int _scrollIdleThresholdMs = 800;

class _TabThemesEpochNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

class _TabHomeEpochNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final _tabThemesEpochProvider = NotifierProvider<_TabThemesEpochNotifier, int>(
  _TabThemesEpochNotifier.new,
);
final _tabHomeEpochProvider = NotifierProvider<_TabHomeEpochNotifier, int>(
  _TabHomeEpochNotifier.new,
);

final tabThemesForStoreProvider =
    FutureProvider.family<TabThemesResponse, String>(
        (Ref ref, String storeKey) async {
  ref.watch(_tabThemesEpochProvider);
  final TabThemesResponse? memory = _themeMemoryCache[storeKey];
  if (memory != null) {
    _scheduleThemeWarmAndPrefetch(ref, storeKey, memory);
    unawaited(_fetchAndCacheTabThemes(ref, storeKey));
    return memory;
  }

  TabThemesResponse response = storeKey == 'zepto'
      ? TabThemesResponse.defaults(storeKey: storeKey)
      : TabThemesResponse.empty(storeKey: storeKey);

  try {
    final dynamic cached =
        HiveService.remoteThemeBox.get(_manifestCacheKey(storeKey));
    if (cached != null) {
      final Map<String, dynamic> map = _decodeToMap(cached);
      if (map.isNotEmpty) {
        response = TabThemesResponse.fromJson(map);
        _themeMemoryCache[storeKey] = response;
        _scheduleThemeWarmAndPrefetch(ref, storeKey, response);
      }
    } else if (storeKey == 'zepto') {
      final dynamic legacyManifest =
          HiveService.remoteThemeBox.get('tab_themes_data');
      final Map<String, dynamic> legacyMap = _decodeToMap(legacyManifest);
      if (legacyMap.isNotEmpty) {
        response = TabThemesResponse.fromJson(legacyMap);
        _themeMemoryCache[storeKey] = response;
        _scheduleThemeWarmAndPrefetch(ref, storeKey, response);
      } else {
        final dynamic legacyTheme = HiveService.remoteThemeBox.get('data');
        final TabThemesResponse? migrated =
            _decodeLegacyTheme(storeKey, legacyTheme);
        if (migrated != null) {
          response = migrated;
          _themeMemoryCache[storeKey] = response;
          _scheduleThemeWarmAndPrefetch(ref, storeKey, response);
        }
      }
    }
  } catch (error) {
    debugPrint('[TabThemes][$storeKey] Hive read failed: $error');
  }

  unawaited(_fetchAndCacheTabThemes(ref, storeKey));
  return response;
});

final tabThemesProvider = FutureProvider<TabThemesResponse>((Ref ref) async {
  final String storeKey = ref.watch(selectedStoreProvider).id;
  return ref.watch(tabThemesForStoreProvider(storeKey).future);
});

final tabThemesSnapshotProvider = Provider<TabThemesResponse?>((Ref ref) {
  ref.watch(_tabThemesEpochProvider);
  final String storeKey = ref.watch(selectedStoreProvider).id;
  return _readCachedManifestSnapshot(storeKey);
});

final activeTabThemeProvider = Provider<RemoteTheme>((Ref ref) {
  final String selectedTabKey = ref.watch(selectedCategoryIdProvider);
  final String? userId = _currentUserId();
  final String storeKey = ref.watch(selectedStoreProvider).id;
  final TabThemesResponse? snapshot = ref.watch(tabThemesSnapshotProvider);
  final AsyncValue<TabThemesResponse> tabThemes = ref.watch(tabThemesProvider);
  final TabThemesResponse response = snapshot ??
      tabThemes.asData?.value ??
      (storeKey == 'zepto'
          ? TabThemesResponse.defaults(storeKey: storeKey)
          : TabThemesResponse.empty(storeKey: storeKey));

  final TabThemeEntry? entry =
      response.tabMap[selectedTabKey] ?? response.defaultTabEntry;
  if (entry == null) {
    return RemoteTheme.defaults();
  }

  return entry.resolveForUser(userId);
});

final remoteThemeProvider = FutureProvider<RemoteTheme>((Ref ref) async {
  final String storeKey = ref.watch(selectedStoreProvider).id;
  final TabThemesResponse? snapshot = ref.watch(tabThemesSnapshotProvider);
  final TabThemesResponse response =
      snapshot ?? await ref.watch(tabThemesProvider.future);
  final String? userId = _currentUserId();
  final TabThemeEntry? allTab = response.tabMap['all'];
  return allTab?.resolveForUser(userId) ??
      (storeKey == 'zepto'
          ? TabThemesResponse.defaults(storeKey: storeKey).tabs.first.themeData
          : RemoteTheme.defaults());
});

final tabHomeContentProvider =
    FutureProvider.family<TabHomeContentResponse?, String>(
        (Ref ref, String providerKey) async {
  ref.watch(_tabHomeEpochProvider);
  final List<String> parts = providerKey.split('::');
  if (parts.length != 2) {
    return null;
  }

  final String storeKey = parts[0];
  final String tabKey = parts[1];
  final String memoryKey = _tabHomeMemoryKey(storeKey, tabKey);
  final TabHomeContentResponse? memory = _tabHomeMemoryCache[memoryKey];
  if (memory != null) {
    unawaited(_fetchAndCacheTabHomeContent(ref, storeKey, tabKey));
    return memory;
  }

  try {
    final dynamic cached =
        HiveService.remoteThemeBox.get(_tabHomeCacheKey(storeKey, tabKey));
    if (cached != null) {
      final Map<String, dynamic> map = _decodeToMap(cached);
      if (map.isNotEmpty) {
        final TabHomeContentResponse response =
            TabHomeContentResponse.fromJson(map);
        _tabHomeMemoryCache[memoryKey] = response;
        unawaited(_fetchAndCacheTabHomeContent(ref, storeKey, tabKey));
        return response;
      }
    }
  } catch (error) {
    debugPrint('[TabHome][$storeKey/$tabKey] Hive read failed: $error');
  }

  return _fetchAndCacheTabHomeContent(ref, storeKey, tabKey);
});

final selectedTabHomeContentProvider =
    FutureProvider<TabHomeContentResponse?>((Ref ref) async {
  final String storeKey = ref.watch(selectedStoreProvider).id;
  final String selectedTabKey = ref.watch(selectedCategoryIdProvider);
  final TabThemesResponse? snapshot = ref.watch(tabThemesSnapshotProvider);
  final TabThemesResponse response =
      snapshot ?? await ref.watch(tabThemesProvider.future);

  final String? resolvedTabKey = _resolveTabKey(response, selectedTabKey);

  if (resolvedTabKey == null) {
    return null;
  }

  return ref.watch(
    tabHomeContentProvider(_tabHomeProviderKey(storeKey, resolvedTabKey))
        .future,
  );
});

final themeRefreshTimerProvider = Provider<Timer>((Ref ref) {
  // PHASE 4A: Scroll-idle-aware theme refresh.
  //
  // The timer still fires every 5 minutes, but if the home scroll is active
  // we defer the provider invalidation until the user stops scrolling.
  // Only one pending refresh is queued at a time — subsequent timer ticks
  // while a deferred refresh is already pending are no-ops.
  //
  // Mechanism:
  //   • _homeScrollLastEventMs is updated by _HomeScreenState on every scroll
  //     tick (set to DateTime.now().millisecondsSinceEpoch).
  //   • A scroll is considered "active" if a scroll event occurred within the
  //     last 800ms.
  //   • When the timer fires during active scroll, a 500ms polling loop checks
  //     every 500ms until the scroll has been idle for 800ms, then runs the
  //     refresh. The loop is bounded to 2 minutes max to prevent infinite deferral.
  Timer? _deferTimer;

  void doRefresh() {
    _themeMemoryCache.clear();
    _tabHomeMemoryCache.clear();
    _tabThemesFetchInFlight.clear();
    _tabHomeFetchInFlight.clear();
    _tabHomePrefetchInFlight.clear();
    _sectionManifestPrefetchInFlight.clear();
    ref
      ..invalidate(tabThemesProvider)
      ..invalidate(selectedTabHomeContentProvider);
  }

  void scheduleWhenIdle() {
    _deferTimer?.cancel();
    final int startMs = DateTime.now().millisecondsSinceEpoch;
    _deferTimer = Timer.periodic(const Duration(milliseconds: 500), (t) {
      final int now = DateTime.now().millisecondsSinceEpoch;
      final bool isScrollActive =
          (now - homeScrollLastEventMs) < _scrollIdleThresholdMs;
      final bool timedOut = (now - startMs) > 120000; // 2-min safety cap

      if (!isScrollActive || timedOut) {
        t.cancel();
        _deferTimer = null;
        doRefresh();
      }
    });
  }

  final Timer timer = Timer.periodic(const Duration(minutes: 5), (_) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final bool isScrollActive =
        (now - homeScrollLastEventMs) < _scrollIdleThresholdMs;

    if (isScrollActive) {
      // Only queue one deferred refresh — if one is already pending, skip.
      if (_deferTimer == null || !_deferTimer!.isActive) {
        scheduleWhenIdle();
      }
    } else {
      doRefresh();
    }
  });

  ref.onDispose(() {
    timer.cancel();
    _deferTimer?.cancel();
  });
  return timer;
});

class _ManagedThemeRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  Future<void> refresh() async {
    final String storeKey = ref.read(selectedStoreProvider).id;
    final String selectedTabKey = ref.read(selectedCategoryIdProvider);

    _themeMemoryCache.remove(storeKey);

    await _fetchAndCacheTabThemes(ref, storeKey);

    final TabThemesResponse response = _themeMemoryCache[storeKey] ??
        _readCachedManifestSnapshot(storeKey) ??
        (storeKey == 'zepto'
            ? TabThemesResponse.defaults(storeKey: storeKey)
            : TabThemesResponse.empty(storeKey: storeKey));

    final String? resolvedTabKey = _resolveTabKey(response, selectedTabKey);
    if (resolvedTabKey != null) {
      final String providerKey = _tabHomeProviderKey(storeKey, resolvedTabKey);
      _tabHomeMemoryCache.remove(_tabHomeMemoryKey(storeKey, resolvedTabKey));
      ref.invalidate(tabHomeContentProvider(providerKey));
      await _fetchAndCacheTabHomeContent(ref, storeKey, resolvedTabKey);
    }

    ref
      ..invalidate(tabThemesForStoreProvider(storeKey))
      ..invalidate(tabThemesProvider)
      ..invalidate(selectedTabHomeContentProvider);

    state++;
  }
}

final managedThemeRefreshProvider =
    NotifierProvider<_ManagedThemeRefreshNotifier, int>(
  _ManagedThemeRefreshNotifier.new,
);

final socketThemeUpdateStreamProvider =
    StreamProvider<Map<String, dynamic>>((Ref ref) {
  return ref.watch(socketServiceProvider).themeUpdateStream;
});

Future<void> refreshCurrentStoreThemes(WidgetRef ref) async {
  await ref.read(managedThemeRefreshProvider.notifier).refresh();
}

Future<void> handleThemeSocketEvent(WidgetRef ref, Map data) async {
  final String storeKey =
      _readSocketStoreKey(data) ?? ref.read(selectedStoreProvider).id;
  final String selectedStoreKey = ref.read(selectedStoreProvider).id;

  _themeMemoryCache.remove(storeKey);
  _tabThemesFetchInFlight.remove(storeKey);
  _tabHomePrefetchInFlight.remove(storeKey);
  _sectionManifestPrefetchInFlight.remove(storeKey);
  _clearTabHomeCachesForStore(storeKey);

  if (storeKey == selectedStoreKey) {
    await refreshCurrentStoreThemes(ref);
    return;
  }

  ref.invalidate(tabThemesForStoreProvider(storeKey));
}

void _scheduleThemeWarmAndPrefetch(
  Ref ref,
  String storeKey,
  TabThemesResponse response,
) {
  unawaited(ThemeAssetWarmer.warmAssets(response));
  unawaited(_prefetchSectionManifests(ref, storeKey, response));
  unawaited(_prefetchTabHomeContent(ref, storeKey, response));
}

Future<void> _prefetchSectionManifests(
  Ref ref,
  String storeKey,
  TabThemesResponse response,
) async {
  if (response.tabs.isEmpty) {
    return;
  }

  if (ref.read(selectedStoreProvider).id != storeKey) {
    return;
  }

  if (!_sectionManifestPrefetchInFlight.add(storeKey)) {
    return;
  }

  try {
    final List<String> prioritizedTabKeys = _prioritizeTabKeys(ref, response);
    for (final String tabKey
        in prioritizedTabKeys.take(_tabHomePrefetchLimit)) {
      await ref.read(sectionManifestProvider(tabKey).future);
      await Future<void>.delayed(Duration.zero);
    }
  } finally {
    _sectionManifestPrefetchInFlight.remove(storeKey);
  }
}

Future<void> _prefetchTabHomeContent(
  Ref ref,
  String storeKey,
  TabThemesResponse response,
) async {
  if (response.tabs.isEmpty) {
    return;
  }

  if (!_tabHomePrefetchInFlight.add(storeKey)) {
    return;
  }

  try {
    final List<String> prioritizedTabKeys = _prioritizeTabKeys(
      ref,
      response,
    );

    for (final String tabKey
        in prioritizedTabKeys.take(_tabHomePrefetchLimit)) {
      await _fetchAndCacheTabHomeContent(ref, storeKey, tabKey);
      await Future<void>.delayed(Duration.zero);
    }
  } finally {
    _tabHomePrefetchInFlight.remove(storeKey);
  }
}

Future<void> _fetchAndCacheTabThemes(Ref ref, String storeKey) {
  final Future<void>? inFlight = _tabThemesFetchInFlight[storeKey];
  if (inFlight != null) {
    return inFlight;
  }

  final Future<void> future = _runFetchAndCacheTabThemes(ref, storeKey);
  _tabThemesFetchInFlight[storeKey] = future;
  future.whenComplete(() {
    if (identical(_tabThemesFetchInFlight[storeKey], future)) {
      _tabThemesFetchInFlight.remove(storeKey);
    }
  });
  return future;
}

Future<void> _runFetchAndCacheTabThemes(Ref ref, String storeKey) async {
  try {
    final Dio dio = _buildDio();
    final Map<String, dynamic> headers = <String, dynamic>{};
    final String? etag = _themeMemoryCache[storeKey]?.etag;
    if (etag != null && etag.isNotEmpty) {
      headers['If-None-Match'] = etag;
    }

    final Response<dynamic> response = await dio.get<dynamic>(
      ApiConstants.tabThemes,
      queryParameters: <String, dynamic>{'store_key': storeKey},
      options: Options(
        headers: headers,
        validateStatus: (int? status) => status != null && status < 500,
      ),
    );

    if (response.statusCode == 304) {
      // Backend healthy — tell availability provider so it can clear any
      // prior service-unavailable state.
      _reportHealthyIfPossible(ref);
      return;
    }

    final dynamic payload = response.data;
    if (payload is! Map) {
      return;
    }

    final Map<String, dynamic> body = Map<String, dynamic>.from(payload);
    if (body['success'] != true || body['data'] is! Map) {
      return;
    }

    final Map<String, dynamic> dataMap =
        Map<String, dynamic>.from(body['data'] as Map<dynamic, dynamic>);
    final String? responseEtag = response.headers.value('etag');
    if (responseEtag != null) {
      dataMap['etag'] = responseEtag;
    }

    final String encodedData = jsonEncode(dataMap);
    final dynamic cachedRaw =
        HiveService.remoteThemeBox.get(_manifestCacheKey(storeKey));
    final String? cachedEncoded = cachedRaw is String
        ? cachedRaw
        : cachedRaw is Map
            ? jsonEncode(cachedRaw)
            : null;

    await HiveService.remoteThemeBox
        .put(_manifestCacheKey(storeKey), encodedData);
    await HiveService.markCached(
      StorageKeys.cacheRemoteThemeForStore(storeKey),
    );

    final TabThemesResponse parsed = TabThemesResponse.fromJson(dataMap);
    _themeMemoryCache[storeKey] = parsed;
    _scheduleThemeWarmAndPrefetch(ref, storeKey, parsed);

    // Successful fetch — clear any service-unavailable flag.
    _reportHealthyIfPossible(ref);

    if (cachedEncoded != encodedData) {
      ref.read(_tabThemesEpochProvider.notifier).bump();
    }
  } catch (error) {
    debugPrint('[TabThemes][$storeKey] API fetch failed (using cache): $error');

    // PHASE 6: If we have no valid cache AND the backend is down, surface the
    // proper offline/error screen instead of silently returning an empty
    // default theme which can render a blank or broken UI.
    final bool hasCachedData = _themeMemoryCache.containsKey(storeKey) ||
        _hasHiveCacheForStore(storeKey);
    if (!hasCachedData) {
      _reportServiceUnavailableIfPossible(ref);
    }
  }
}

/// Whether there is any Hive-cached theme payload for [storeKey].
bool _hasHiveCacheForStore(String storeKey) {
  try {
    final dynamic cached =
        HiveService.remoteThemeBox.get(_manifestCacheKey(storeKey));
    if (cached != null) return true;
    // Also check legacy zepto keys.
    if (storeKey == 'zepto') {
      return HiveService.remoteThemeBox.get('tab_themes_data') != null ||
          HiveService.remoteThemeBox.get('data') != null;
    }
    return false;
  } catch (_) {
    return false;
  }
}

void _reportHealthyIfPossible(Ref ref) {
  try {
    ref.read(appAvailabilityProvider.notifier).reportHealthy();
  } catch (_) {
    // Provider may not be available in all contexts (e.g. during prefetch).
  }
}

void _reportServiceUnavailableIfPossible(Ref ref) {
  try {
    ref.read(appAvailabilityProvider.notifier).reportServiceUnavailable();
  } catch (_) {
    // Provider may not be available in all contexts.
  }
}

Future<TabHomeContentResponse?> _fetchAndCacheTabHomeContent(
  Ref ref,
  String storeKey,
  String tabKey,
) {
  final String requestKey = _tabHomeProviderKey(storeKey, tabKey);
  final Future<TabHomeContentResponse?>? inFlight =
      _tabHomeFetchInFlight[requestKey];
  if (inFlight != null) {
    return inFlight;
  }

  final Future<TabHomeContentResponse?> future =
      _runFetchAndCacheTabHomeContent(ref, storeKey, tabKey);
  _tabHomeFetchInFlight[requestKey] = future;
  future.whenComplete(() {
    if (identical(_tabHomeFetchInFlight[requestKey], future)) {
      _tabHomeFetchInFlight.remove(requestKey);
    }
  });
  return future;
}

Future<TabHomeContentResponse?> _runFetchAndCacheTabHomeContent(
  Ref ref,
  String storeKey,
  String tabKey,
) async {
  try {
    final Dio dio = _buildDio();
    final Response<dynamic> response = await dio.get<dynamic>(
      '${ApiConstants.tabThemes}/$tabKey/home',
      queryParameters: <String, dynamic>{'store_key': storeKey},
      options: Options(
        validateStatus: (int? status) => status != null && status < 500,
      ),
    );

    if (response.statusCode == 404) {
      return null;
    }

    final dynamic payload = response.data;
    if (payload is! Map) {
      return null;
    }

    final Map<String, dynamic> body = Map<String, dynamic>.from(payload);
    if (body['success'] != true || body['data'] is! Map) {
      return null;
    }

    final Map<String, dynamic> dataMap =
        Map<String, dynamic>.from(body['data'] as Map<dynamic, dynamic>);
    final String encodedData = jsonEncode(dataMap);
    final String cacheKey = _tabHomeCacheKey(storeKey, tabKey);
    final dynamic cachedRaw = HiveService.remoteThemeBox.get(cacheKey);
    final String? cachedEncoded = cachedRaw is String
        ? cachedRaw
        : cachedRaw is Map
            ? jsonEncode(cachedRaw)
            : null;

    await HiveService.remoteThemeBox.put(cacheKey, encodedData);
    await HiveService.markCached(
      StorageKeys.cacheRemoteThemeHome(storeKey, tabKey),
    );

    final TabHomeContentResponse parsed =
        TabHomeContentResponse.fromJson(dataMap);
    _tabHomeMemoryCache[_tabHomeMemoryKey(storeKey, tabKey)] = parsed;

    if (cachedEncoded != encodedData) {
      ref.read(_tabHomeEpochProvider.notifier).bump();
    }

    return parsed;
  } catch (error) {
    debugPrint('[TabHome][$storeKey/$tabKey] API fetch failed: $error');
    return null;
  }
}

List<String> _prioritizeTabKeys(
  Ref ref,
  TabThemesResponse response,
) {
  final List<String> ordered = <String>[];
  final String? selectedTabKey = _resolveTabKey(
    response,
    ref.read(selectedCategoryIdProvider),
  );

  void addKey(String? key) {
    if (key == null || key.isEmpty || ordered.contains(key)) {
      return;
    }
    ordered.add(key);
  }

  addKey(selectedTabKey);
  addKey(response.defaultTabEntry?.tabKey);
  for (final TabThemeEntry tab in response.tabs) {
    addKey(tab.tabKey);
  }

  return List<String>.unmodifiable(ordered);
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

TabThemesResponse? _decodeLegacyTheme(String storeKey, dynamic cached) {
  final Map<String, dynamic> map = _decodeToMap(cached);
  if (map.isEmpty) {
    return null;
  }

  final TabThemeEntry defaultEntry = TabThemeEntry(
    storeKey: storeKey,
    tabId: null,
    themeId: null,
    tabKey: 'all',
    tabLabel: 'All',
    tabIconUrl: null,
    tabTextColor: Colors.black,
    tabOrder: 0,
    variant: 'A',
    themeData: RemoteTheme.fromJson(map),
  );

  return TabThemesResponse(
    storeKey: storeKey,
    etag: null,
    tabs: <TabThemeEntry>[defaultEntry],
    tabMap: <String, TabThemeEntry>{'all': defaultEntry},
  );
}

TabThemesResponse? _readCachedManifestSnapshot(String storeKey) {
  final TabThemesResponse? memory = _themeMemoryCache[storeKey];
  if (memory != null) {
    return memory;
  }

  try {
    final dynamic cached =
        HiveService.remoteThemeBox.get(_manifestCacheKey(storeKey));
    final Map<String, dynamic> map = _decodeToMap(cached);
    if (map.isNotEmpty) {
      final TabThemesResponse response = TabThemesResponse.fromJson(map);
      _themeMemoryCache[storeKey] = response;
      return response;
    }

    if (storeKey == 'zepto') {
      final dynamic legacyManifest =
          HiveService.remoteThemeBox.get('tab_themes_data');
      final Map<String, dynamic> legacyMap = _decodeToMap(legacyManifest);
      if (legacyMap.isNotEmpty) {
        final TabThemesResponse response =
            TabThemesResponse.fromJson(legacyMap);
        _themeMemoryCache[storeKey] = response;
        return response;
      }

      final TabThemesResponse? migrated = _decodeLegacyTheme(
        storeKey,
        HiveService.remoteThemeBox.get('data'),
      );
      if (migrated != null) {
        _themeMemoryCache[storeKey] = migrated;
        return migrated;
      }
    }
  } catch (error) {
    debugPrint('[TabThemes][$storeKey] Snapshot read failed: $error');
  }

  return null;
}

Dio _buildDio() {
  return Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      // Match the main DioClient timeout so mobile-data / Cloudflare tunnel
      // latency doesn't cause theme fetches to silently fail (previously 5s).
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 40),
    ),
  );
}

String _manifestCacheKey(String storeKey) => 'tab_themes_data_$storeKey';

String _tabHomeCacheKey(String storeKey, String tabKey) =>
    'tab_home_data_${storeKey}_$tabKey';

String _tabHomeMemoryKey(String storeKey, String tabKey) =>
    '$storeKey::$tabKey';

String _tabHomeProviderKey(String storeKey, String tabKey) =>
    '$storeKey::$tabKey';

String? _resolveTabKey(TabThemesResponse response, String selectedTabKey) {
  if (response.tabMap.containsKey(selectedTabKey)) {
    return selectedTabKey;
  }
  return response.defaultTabEntry?.tabKey;
}

String? _currentUserId() {
  final dynamic cachedUser = HiveService.userBox.get('user');
  if (cachedUser is Map) {
    final Map<String, dynamic> user = Map<String, dynamic>.from(cachedUser);
    final dynamic idValue = user['id'] ?? user['userId'];
    if (idValue is String && idValue.trim().isNotEmpty) {
      return idValue.trim();
    }
  }
  return null;
}

void _clearTabHomeCachesForStore(String storeKey) {
  final List<String> keys = _tabHomeMemoryCache.keys
      .where((String key) => key.startsWith('$storeKey::'))
      .toList(growable: false);

  for (final String key in keys) {
    _tabHomeMemoryCache.remove(key);
    _tabHomeFetchInFlight.remove(key);
  }
}

String? _readSocketStoreKey(Map data) {
  final dynamic value = data['storeKey'] ?? data['store_key'];
  if (value == null) {
    return null;
  }

  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}
