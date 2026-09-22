import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/network/api_interceptor.dart';
import 'package:bakaloo_flutter_app/core/network/app_availability_provider.dart';
import 'package:bakaloo_flutter_app/core/providers/storefront_scope_provider.dart';
import 'package:bakaloo_flutter_app/core/providers/store_provider.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_service.dart';
import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/core/storage/secure_storage_service.dart';
import 'package:bakaloo_flutter_app/core/theme/layout_flight.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/tab_home_content_model.dart';
import 'package:bakaloo_flutter_app/core/theme/theme_asset_warmer.dart';

// The Theme Builder (backend `/theme/tabs`) is the ONLY source of storefront
// chrome. There is no bundled fallback theme: while a shop's theme is
// unresolved the UI shows [RemoteTheme.neutral] placeholders — never another
// shop's theme and never a legacy one.
//
// Every cache below is addressed by an immutable key captured when the request
// STARTS (`ThemeScopeKey` / `SectionScopeKey`). Providers watch the storefront
// scope, so a change of shop / price mode re-keys them and nothing cached for
// the previous scope can be read again.

// PHASE 4A: Scroll-idle signalling.
// Updated by _HomeScreenState on every scroll event. Module-level so the
// refresh timer can read it without coupling to the widget.
// Epoch milliseconds of the last scroll event; 0 = no scroll yet.
int homeScrollLastEventMs = 0;

/// Test seams: a fake HTTP client / health sink, and a reset of the static
/// memory caches between tests. Production never touches these.
@visibleForTesting
Dio Function()? layoutDioFactory;

@visibleForTesting
void Function({required bool healthy})? layoutHealthHook;

Dio? _sharedDio;

Dio buildLayoutDio() {
  final Dio Function()? factory = layoutDioFactory;
  if (factory != null) {
    return factory();
  }
  return _sharedDio ??= _buildDio();
}

Dio _buildDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      // Layout requests are cheap cacheable GETs and the last good content
      // stays on screen while we retry, so fail fast rather than spin.
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
    ),
  );
  dio.interceptors.add(ApiInterceptor(SecureStorageService()));
  return dio;
}

void reportLayoutHealth(Ref ref, {required bool healthy}) {
  final hook = layoutHealthHook;
  if (hook != null) {
    hook(healthy: healthy);
    return;
  }
  try {
    final notifier = ref.read(appAvailabilityProvider.notifier);
    healthy ? notifier.reportHealthy() : notifier.reportServiceUnavailable();
  } catch (_) {
    // Provider may not be available in all contexts (e.g. during prefetch).
  }
}

// ─── Theme manifest ──────────────────────────────────────────────────────────

final LayoutMemory<TabThemesResponse> _themeMemory =
    LayoutMemory<TabThemesResponse>(8);
final FlightBoard<TabThemesResponse> _themeBoard =
    FlightBoard<TabThemesResponse>();
final LayoutMemory<TabHomeContentResponse> _tabHomeMemory =
    LayoutMemory<TabHomeContentResponse>(48);
final FlightBoard<TabHomeContentResponse> _tabHomeBoard =
    FlightBoard<TabHomeContentResponse>();

String themeChangeId(ThemeScopeKey key) => 'theme:${key.id}';
String tabHomeChangeId(SectionScopeKey key) => 'tabhome:${key.id}';

String _themeStorageKey(ThemeScopeKey key) => AppCacheManager.scopedKey(
      'layout_theme_v3',
      shopScope: key.shopScope,
      extra: key.storeKey,
    );

String _tabHomeStorageKey(SectionScopeKey key) => AppCacheManager.scopedKey(
      'layout_tabhome_v3',
      shopScope: key.shopScope,
      extra: '${key.storeKey}|${key.priceMode}|${key.tabKey}',
    );

/// Memory, then disk. Content restored from disk is stale (revalidated on
/// first use in this process) but renders immediately.
Held<TabThemesResponse>? peekTheme(ThemeScopeKey key) {
  if (key.isUnresolved) {
    // No shop, no storefront: nothing is ever stored for (or read from) it.
    return null;
  }
  final Held<TabThemesResponse>? cached = _themeMemory.get(key.id);
  if (cached != null) {
    return cached;
  }
  final stored = decodeLayoutEnvelope(
    layoutPersistence.read(LayoutBox.theme, _themeStorageKey(key)),
  );
  if (stored == null) {
    return null;
  }
  try {
    final Held<TabThemesResponse> held = Held<TabThemesResponse>(
      data: TabThemesResponse.fromJson(
        withEtag(decodeLayoutMap(stored.raw), stored.etag),
      ),
      raw: stored.raw,
      fetchedAt: kLayoutEpoch,
      etag: stored.etag,
    );
    _themeMemory.put(key.id, held);
    return held;
  } catch (error) {
    debugPrint('[TabThemes][${key.id}] unreadable cache dropped: $error');
    return null;
  }
}

/// Fetches (or joins an in-flight fetch of) the theme manifest for [key].
/// With [deferCommit] the result is applied only when `outcome.commit()` is
/// called, so it can land in the same frame as other resources.
LayoutClaim<TabThemesResponse> claimTheme(
  ThemeScopeKey key, {
  bool deferCommit = false,
}) {
  return _themeBoard.claim(
    key.id,
    (CancelToken token) => revalidateLayoutResource<TabThemesResponse>(
      dio: buildLayoutDio(),
      path: ApiConstants.tabThemes,
      query: <String, dynamic>{'store_key': key.storeKey},
      current: _themeMemory.get(key.id) ?? peekTheme(key),
      token: token,
      parse: TabThemesResponse.fromJson,
      accept: (Map<String, dynamic> data) =>
          payloadMatchesShopScope(data, key.shopScope),
      apply: (Held<TabThemesResponse> next, {required bool changed}) {
        _themeMemory.put(key.id, next);
        unawaited(
          layoutPersistence.write(
            LayoutBox.theme,
            _themeStorageKey(key),
            encodeLayoutEnvelope(
              raw: next.raw,
              savedAt: next.fetchedAt,
              etag: next.etag,
            ),
          ),
        );
        if (changed) {
          layoutChanges.add(themeChangeId(key));
        }
      },
    ),
    deferCommit: deferCommit,
  );
}

/// `shopId`, when given, narrows to exactly that shop (id format is
/// `storeKey|shopScope`) — used when a dashboard event names the specific
/// shop it was about, so an edit to Kolkata's theme does not mark a Delhi
/// customer's cached theme stale too.
void markThemeStale({String? storeKey, String? shopId}) =>
    _themeMemory.markStale(
      (String id) {
        final List<String> parts = id.split('|');
        return (storeKey == null || parts[0] == storeKey) &&
            (shopId == null || parts[1] == shopId);
      },
    );

// ─── Tab-home content (products for sections that carry none) ────────────────

Held<TabHomeContentResponse>? peekTabHome(SectionScopeKey key) {
  if (key.isUnresolved) {
    return null;
  }
  final Held<TabHomeContentResponse>? cached = _tabHomeMemory.get(key.id);
  if (cached != null) {
    return cached;
  }
  final stored = decodeLayoutEnvelope(
    layoutPersistence.read(LayoutBox.tabHome, _tabHomeStorageKey(key)),
  );
  if (stored == null) {
    return null;
  }
  try {
    final Held<TabHomeContentResponse> held = Held<TabHomeContentResponse>(
      data: TabHomeContentResponse.fromJson(decodeLayoutMap(stored.raw)),
      raw: stored.raw,
      fetchedAt: kLayoutEpoch,
      etag: stored.etag,
    );
    _tabHomeMemory.put(key.id, held);
    return held;
  } catch (error) {
    debugPrint('[TabHome][${key.id}] unreadable cache dropped: $error');
    return null;
  }
}

LayoutClaim<TabHomeContentResponse> claimTabHome(
  SectionScopeKey key, {
  bool deferCommit = false,
}) {
  return _tabHomeBoard.claim(
    key.id,
    (CancelToken token) => revalidateLayoutResource<TabHomeContentResponse>(
      dio: buildLayoutDio(),
      path: '${ApiConstants.tabThemes}/${key.tabKey}/home',
      // Sent explicitly so the request always matches the key it is stored
      // under, even if the customer flips B2C/B2B while it is in flight.
      query: <String, dynamic>{
        'store_key': key.storeKey,
        'priceMode': key.priceMode,
      },
      current: _tabHomeMemory.get(key.id) ?? peekTabHome(key),
      token: token,
      parse: TabHomeContentResponse.fromJson,
      accept: (Map<String, dynamic> data) =>
          payloadMatchesShopScope(data, key.shopScope),
      apply: (Held<TabHomeContentResponse> next, {required bool changed}) {
        _tabHomeMemory.put(key.id, next);
        unawaited(
          layoutPersistence.write(
            LayoutBox.tabHome,
            _tabHomeStorageKey(key),
            encodeLayoutEnvelope(
              raw: next.raw,
              savedAt: next.fetchedAt,
              etag: next.etag,
            ),
          ),
        );
        if (changed) {
          layoutChanges.add(tabHomeChangeId(key));
        }
      },
    ),
    deferCommit: deferCommit,
  );
}

/// `shopId`, when given, narrows to exactly that shop — see [markThemeStale].
void markTabHomeStale({String? storeKey, String? shopId, String? tabKey}) =>
    _tabHomeMemory.markStale((String id) {
      final List<String> parts = id.split('|');
      return (storeKey == null || parts[0] == storeKey) &&
          (shopId == null || parts[1] == shopId) &&
          (tabKey == null || parts.last == tabKey);
    });

void resetLayoutMemoryForTests() {
  _themeMemory.clear();
  _tabHomeMemory.clear();
  _themeBoard.cancelAll();
  _tabHomeBoard.cancelAll();
  _themeRetries.clear();
  _sharedDio = null;
  resetSectionLayoutForTests();
}

// ─── Providers ───────────────────────────────────────────────────────────────

/// Theme key of the active storefront (store + shop scope).
final activeThemeKeyProvider = Provider<ThemeScopeKey>((Ref ref) {
  return ref.watch(
    storefrontScopeProvider.select((StorefrontScope s) => s.themeKey),
  );
});

/// Re-runs the owning provider when its resource changes. Only the provider of
/// the CHANGED key rebuilds — there is no global epoch that rebuilds (and
/// re-fetches) every family member.
void _rebuildOnChange(Ref ref, String changeId) {
  final StreamSubscription<String> sub =
      layoutChanges.stream.where((String id) => id == changeId).listen((_) {
    if (ref.mounted) {
      ref.invalidateSelf();
    }
  });
  ref.onDispose(sub.cancel);
}

final Map<String, int> _themeRetries = <String, int>{};
const int _maxFirstLoadRetries = 3;

final tabThemesForStoreProvider = FutureProvider.autoDispose
    .family<TabThemesResponse, ThemeScopeKey>(
        (Ref ref, ThemeScopeKey key) async {
  if (key.isUnresolved) {
    // No shop resolved yet (a guest that has not been located, an account
    // whose allocation has not arrived): there is no storefront to fetch, and
    // asking anonymously would return the platform default — the wrong-theme
    // flash. Stay in loading (placeholders) until the scope changes, which
    // disposes this provider and builds the real one.
    return Completer<TabThemesResponse>().future;
  }
  _rebuildOnChange(ref, themeChangeId(key));

  final Held<TabThemesResponse>? held = peekTheme(key);
  if (held != null) {
    unawaited(ThemeAssetWarmer.warmAssets(held.data));
    if (!held.isFresh) {
      // Background revalidation. Released with the provider: if the customer
      // has moved on, the request is aborted (unless somebody else needs it).
      final LayoutClaim<TabThemesResponse> claim = claimTheme(key);
      ref.onDispose(claim.release);
    }
    return held.data;
  }

  // Genuine first load for this (store, shop): nothing to show yet.
  final LayoutClaim<TabThemesResponse> claim = claimTheme(key);
  ref.onDispose(claim.release);
  final FetchOutcome<TabThemesResponse> outcome = await claim.result;
  final Held<TabThemesResponse>? fresh = outcome.held;
  if (fresh != null) {
    _themeRetries.remove(key.id);
    if (ref.mounted) {
      reportLayoutHealth(ref, healthy: true);
    }
    unawaited(ThemeAssetWarmer.warmAssets(fresh.data));
    return fresh.data;
  }
  if (outcome.status != FetchStatus.cancelled && ref.mounted) {
    // Offline/unreachable with nothing cached: surface the availability
    // screen and retry a few times with backoff. A response for another shop
    // (StorefrontScopeMismatch) is not an outage: keep the placeholders and
    // retry — the scope/credentials converge within moments.
    if (outcome.error is! StorefrontScopeMismatch) {
      reportLayoutHealth(ref, healthy: false);
    }
    final int attempt = (_themeRetries[key.id] ?? 0) + 1;
    if (attempt <= _maxFirstLoadRetries) {
      _themeRetries[key.id] = attempt;
      final Timer retry = Timer(Duration(seconds: 3 * attempt), () {
        if (ref.mounted) {
          ref.invalidateSelf();
        }
      });
      ref.onDispose(retry.cancel);
    }
  }
  throw outcome.error ?? const LayoutUnavailableException();
});

/// Theme manifest of the active storefront.
///
/// A plain pass-through (not an async provider that awaits the family's
/// `.future`): an async intermediary would keep the previous shop's provider —
/// and its in-flight request — alive until its own pending build finished,
/// instead of releasing it the moment the customer moves on.
final tabThemesProvider = Provider<AsyncValue<TabThemesResponse>>((Ref ref) {
  final ThemeScopeKey key = ref.watch(activeThemeKeyProvider);
  return ref.watch(tabThemesForStoreProvider(key));
});

/// Synchronous view of the active storefront's held theme (memory/disk) — what
/// makes a cold start and a tab/shop return render on the very first frame.
/// Null until THIS shop's theme has been loaded once; never another shop's.
final tabThemesSnapshotProvider = Provider<TabThemesResponse?>((Ref ref) {
  final ThemeScopeKey key = ref.watch(activeThemeKeyProvider);
  _rebuildOnChange(ref, themeChangeId(key));
  return peekTheme(key)?.data;
});

final RemoteTheme _neutralTheme = RemoteTheme.neutral();

final activeTabThemeProvider = Provider<RemoteTheme>((Ref ref) {
  final String selectedTabKey = ref.watch(selectedCategoryIdProvider);
  final String? userId = _currentUserId();
  final TabThemesResponse? snapshot = ref.watch(tabThemesSnapshotProvider);
  final TabThemesResponse? response =
      snapshot ?? ref.watch(tabThemesProvider).asData?.value;

  final TabThemeEntry? entry = response == null
      ? null
      : response.tabMap[selectedTabKey] ?? response.defaultTabEntry;
  if (entry == null) {
    return _neutralTheme;
  }
  return entry.resolveForUser(userId);
});

/// True once the active storefront's own theme is available.
final themeResolvedProvider = Provider<bool>((Ref ref) {
  return ref.watch(tabThemesSnapshotProvider) != null ||
      ref.watch(tabThemesProvider).asData != null;
});

final tabHomeContentProvider = FutureProvider.autoDispose
    .family<TabHomeContentResponse?, SectionScopeKey>(
        (Ref ref, SectionScopeKey key) async {
  if (key.isUnresolved) {
    return null;
  }
  _rebuildOnChange(ref, tabHomeChangeId(key));

  final Held<TabHomeContentResponse>? held = peekTabHome(key);
  if (held != null) {
    if (!held.isFresh) {
      final LayoutClaim<TabHomeContentResponse> claim = claimTabHome(key);
      ref.onDispose(claim.release);
    }
    return held.data;
  }
  final LayoutClaim<TabHomeContentResponse> claim = claimTabHome(key);
  ref.onDispose(claim.release);
  final FetchOutcome<TabHomeContentResponse> outcome = await claim.result;
  return outcome.held?.data;
});

final selectedTabHomeContentProvider =
    Provider<AsyncValue<TabHomeContentResponse?>>((Ref ref) {
  final SectionScopeKey key = ref.watch(activeSectionKeyProvider);
  return ref.watch(tabHomeContentProvider(key));
});

// ─── Refresh entry points (names kept for the screens that use them) ─────────

final themeRefreshTimerProvider = Provider<Timer>((Ref ref) {
  // Every 5 minutes revalidate the visible storefront IN PLACE (ETag ⇒ usually
  // a 304). Nothing is cleared and nothing is invalidated, so the screen never
  // blanks. If the home scroll is active the refresh waits until it is idle.
  Timer? deferTimer;

  void refreshNow() =>
      unawaited(ref.read(storefrontSyncProvider).revalidateActive(force: true));

  final Timer timer = Timer.periodic(const Duration(minutes: 5), (_) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final bool scrolling = (now - homeScrollLastEventMs) < 800;
    if (!scrolling) {
      refreshNow();
      return;
    }
    if (deferTimer?.isActive ?? false) {
      return;
    }
    final int startMs = now;
    deferTimer = Timer.periodic(const Duration(milliseconds: 500), (Timer t) {
      final int later = DateTime.now().millisecondsSinceEpoch;
      final bool stillScrolling = (later - homeScrollLastEventMs) < 800;
      if (!stillScrolling || later - startMs > 120000) {
        t.cancel();
        refreshNow();
      }
    });
  });

  ref.onDispose(() {
    timer.cancel();
    deferTimer?.cancel();
  });
  return timer;
});

final socketThemeUpdateStreamProvider =
    StreamProvider<Map<String, dynamic>>((Ref ref) {
  return ref.watch(socketServiceProvider).themeUpdateStream;
});

Future<void> refreshCurrentStoreThemes(WidgetRef ref) async {
  await ref.read(storefrontSyncProvider).revalidateActive(force: true);
}

Future<void> handleThemeSocketEvent(WidgetRef ref, Map data) async {
  ref
      .read(storefrontSyncProvider)
      .onThemeEvent(Map<String, dynamic>.from(data));
}

String? _currentUserId() {
  try {
    final dynamic cachedUser = HiveService.userBox.get('user');
    if (cachedUser is Map) {
      final Map<String, dynamic> user = Map<String, dynamic>.from(cachedUser);
      final dynamic idValue = user['id'] ?? user['userId'];
      if (idValue is String && idValue.trim().isNotEmpty) {
        return idValue.trim();
      }
    }
  } catch (_) {
    // Hive not ready (very early startup / tests): no A/B bucketing.
  }
  return null;
}
