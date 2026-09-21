import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/providers/storefront_scope_provider.dart';
import 'package:bakaloo_flutter_app/core/providers/store_provider.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_service.dart';
import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
import 'package:bakaloo_flutter_app/core/theme/layout_flight.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_model.dart';
import 'package:bakaloo_flutter_app/core/theme/tab_home_content_model.dart';
import 'package:bakaloo_flutter_app/core/theme/theme_asset_warmer.dart';

final LayoutMemory<SectionManifestResponse> _sectionMemory =
    LayoutMemory<SectionManifestResponse>(48);
final FlightBoard<SectionManifestResponse> _sectionBoard =
    FlightBoard<SectionManifestResponse>();
final Map<String, int> _sectionRetries = <String, int>{};

String sectionChangeId(SectionScopeKey key) => 'sections:${key.id}';

String _sectionStorageKey(SectionScopeKey key) => AppCacheManager.scopedKey(
      'layout_sections_v3',
      shopScope: key.shopScope,
      extra: '${key.storeKey}|${key.priceMode}|${key.tabKey}',
    );

void resetSectionLayoutForTests() {
  _sectionMemory.clear();
  _sectionBoard.cancelAll();
  _sectionRetries.clear();
}

/// Memory, then disk (disk-restored content is stale but renders at once).
Held<SectionManifestResponse>? peekSections(SectionScopeKey key) {
  final Held<SectionManifestResponse>? cached = _sectionMemory.get(key.id);
  if (cached != null) {
    return cached;
  }
  final stored = decodeLayoutEnvelope(
    layoutPersistence.read(LayoutBox.sections, _sectionStorageKey(key)),
  );
  if (stored == null) {
    return null;
  }
  try {
    final Held<SectionManifestResponse> held = Held<SectionManifestResponse>(
      data: SectionManifestResponse.fromJson(
        withEtag(decodeLayoutMap(stored.raw), stored.etag),
      ),
      raw: stored.raw,
      fetchedAt: kLayoutEpoch,
      etag: stored.etag,
    );
    _sectionMemory.put(key.id, held);
    return held;
  } catch (error) {
    return null;
  }
}

/// Fetches (or joins an in-flight fetch of) the manifest for [key].
LayoutClaim<SectionManifestResponse> claimSections(
  SectionScopeKey key, {
  bool deferCommit = false,
}) {
  return _sectionBoard.claim(
    key.id,
    (CancelToken token) => revalidateLayoutResource<SectionManifestResponse>(
      dio: buildLayoutDio(),
      path: '${ApiConstants.sectionManifest}/${key.tabKey}/sections',
      // priceMode is sent explicitly (not left to the interceptor) so the
      // request always matches the key it is stored under, even if the
      // customer flips B2C/B2B while it is in flight.
      query: <String, dynamic>{
        'store_key': key.storeKey,
        'priceMode': key.priceMode,
      },
      current: _sectionMemory.get(key.id) ?? peekSections(key),
      token: token,
      parse: SectionManifestResponse.fromJson,
      apply: (Held<SectionManifestResponse> next, {required bool changed}) {
        _sectionMemory.put(key.id, next);
        unawaited(
          layoutPersistence.write(
            LayoutBox.sections,
            _sectionStorageKey(key),
            encodeLayoutEnvelope(
              raw: next.raw,
              savedAt: next.fetchedAt,
              etag: next.etag,
            ),
          ),
        );
        if (changed) {
          layoutChanges.add(sectionChangeId(key));
        }
      },
    ),
    deferCommit: deferCommit,
  );
}

void markSectionsStale({String? storeKey, String? tabKey}) =>
    _sectionMemory.markStale((String id) {
      final List<String> parts = id.split('|');
      return (storeKey == null || parts.first == storeKey) &&
          (tabKey == null || parts.last == tabKey);
    });

// ─── Providers ───────────────────────────────────────────────────────────────

final socketSectionUpdateStreamProvider =
    StreamProvider<Map<String, dynamic>>((Ref ref) {
  return ref.watch(socketServiceProvider).sectionUpdateStream;
});

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

/// Key of the manifest being shown: active (store, shop, price mode) + tab.
final activeSectionKeyProvider = Provider<SectionScopeKey>((Ref ref) {
  final StorefrontScope scope = ref.watch(storefrontScopeProvider);
  return scope.sectionKey(ref.watch(activeTabKeyProvider));
});

/// Manifest of one tab of one storefront. autoDispose: switching tab (or shop)
/// releases the old tab's request, which is aborted unless something else
/// still needs it — so the latest selection always wins.
final sectionManifestProvider = FutureProvider.autoDispose
    .family<SectionManifestResponse, SectionScopeKey>(
        (Ref ref, SectionScopeKey key) async {
  final StreamSubscription<String> sub = layoutChanges.stream
      .where((String id) => id == sectionChangeId(key))
      .listen((_) {
    if (ref.mounted) {
      ref.invalidateSelf();
    }
  });
  ref.onDispose(sub.cancel);

  final Held<SectionManifestResponse>? held = peekSections(key);
  if (held != null) {
    unawaited(ThemeAssetWarmer.warmSectionManifest(held.data));
    if (!held.isFresh) {
      final LayoutClaim<SectionManifestResponse> claim = claimSections(key);
      ref.onDispose(claim.release);
    }
    return held.data;
  }

  final LayoutClaim<SectionManifestResponse> claim = claimSections(key);
  ref.onDispose(claim.release);
  final FetchOutcome<SectionManifestResponse> outcome = await claim.result;
  final Held<SectionManifestResponse>? fresh = outcome.held;
  if (fresh != null) {
    _sectionRetries.remove(key.id);
    unawaited(ThemeAssetWarmer.warmSectionManifest(fresh.data));
    return fresh.data;
  }
  if (outcome.status != FetchStatus.cancelled && ref.mounted) {
    final int attempt = (_sectionRetries[key.id] ?? 0) + 1;
    if (attempt <= 3) {
      _sectionRetries[key.id] = attempt;
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

final activeSectionManifestProvider = Provider<SectionManifestResponse>(
  (Ref ref) {
    final SectionScopeKey key = ref.watch(activeSectionKeyProvider);
    final AsyncValue<SectionManifestResponse> manifest =
        ref.watch(sectionManifestProvider(key));

    // asData is null while (re)loading, so a previous key's data can never
    // leak through; the memory fallback is for THIS exact key and is what makes
    // a return to a loaded tab render on the first frame.
    return manifest.asData?.value ??
        peekSections(key)?.data ??
        SectionManifestResponse.empty;
  },
);

enum SectionsStatus {
  /// First load for this (store, shop, mode, tab): nothing to show yet.
  loading,

  /// A manifest is held (it may legitimately contain zero sections).
  ready,

  /// First load failed and nothing is held.
  failed,
}

final activeSectionsStatusProvider = Provider<SectionsStatus>((Ref ref) {
  final SectionScopeKey key = ref.watch(activeSectionKeyProvider);
  final AsyncValue<SectionManifestResponse> manifest =
      ref.watch(sectionManifestProvider(key));
  if (manifest.asData != null || peekSections(key) != null) {
    return SectionsStatus.ready;
  }
  return manifest.hasError ? SectionsStatus.failed : SectionsStatus.loading;
});

// ─── Storefront sync ─────────────────────────────────────────────────────────

/// How long dashboard events are coalesced before ONE revalidation runs.
const Duration kStorefrontSyncDebounce = Duration(milliseconds: 350);

/// Keeps the visible storefront current.
///
/// A refresh fetches the theme AND the active tab (manifest + tab-home) and
/// commits them all in the same synchronous block, so the screen moves from the
/// old layout to the new one in a single frame — never new chrome with old
/// sections. It revalidates in place (ETag ⇒ usually 304): nothing is cleared
/// and nothing is invalidated, so the screen never blanks.
class StorefrontSync {
  StorefrontSync(this._ref);

  final Ref _ref;
  Timer? _debounce;
  bool _disposed = false;

  Future<void> revalidateActive({bool force = false}) async {
    if (_disposed) {
      return;
    }
    final StorefrontScope scope = _ref.read(storefrontScopeProvider);
    final SectionScopeKey sectionKey =
        scope.sectionKey(_ref.read(activeTabKeyProvider));
    final ThemeScopeKey themeKey = scope.themeKey;

    final Held<TabThemesResponse>? theme = peekTheme(themeKey);
    final Held<SectionManifestResponse>? sections = peekSections(sectionKey);
    final Held<TabHomeContentResponse>? tabHome = peekTabHome(sectionKey);

    final List<LayoutClaim<Object?>> claims = <LayoutClaim<Object?>>[];
    if (force || theme == null || !theme.isFresh) {
      claims.add(claimTheme(themeKey, deferCommit: true));
    }
    if (force || sections == null || !sections.isFresh) {
      claims.add(claimSections(sectionKey, deferCommit: true));
    }
    // Tab-home is a fallback product source; refresh it only if it is in use.
    if (tabHome != null && (force || !tabHome.isFresh)) {
      claims.add(claimTabHome(sectionKey, deferCommit: true));
    }
    if (claims.isEmpty) {
      return;
    }

    try {
      final List<FetchOutcome<Object?>> outcomes =
          await Future.wait<FetchOutcome<Object?>>(
        claims.map((LayoutClaim<Object?> c) => c.result),
      );
      if (_disposed) {
        return;
      }
      // One synchronous block ⇒ one frame.
      for (final FetchOutcome<Object?> outcome in outcomes) {
        outcome.commit();
      }
    } finally {
      for (final LayoutClaim<Object?> claim in claims) {
        claim.release();
      }
    }
  }

  /// Dashboard changed a theme. Marks that storefront's held content stale (it
  /// keeps rendering) and, when it is the visible one, refreshes it.
  void onThemeEvent(Map<String, dynamic> data) {
    final String current = _ref.read(storefrontScopeProvider).storeKey;
    final String storeKey = _readString(data['storeKey'] ?? data['store_key']) ??
        current;
    markThemeStale(storeKey: storeKey);
    if (storeKey == current) {
      _scheduleRevalidate();
    }
  }

  /// Dashboard changed a tab's sections.
  void onSectionEvent(Map<String, dynamic> data) {
    final String current = _ref.read(storefrontScopeProvider).storeKey;
    final String storeKey = _readString(data['storeKey'] ?? data['store_key']) ??
        current;
    final String? tabKey = _readString(data['tab_key'] ?? data['tabKey']);
    markSectionsStale(storeKey: storeKey, tabKey: tabKey);
    markTabHomeStale(storeKey: storeKey, tabKey: tabKey);
    if (storeKey != current) {
      return;
    }
    if (tabKey == null || tabKey == _ref.read(activeTabKeyProvider)) {
      _scheduleRevalidate();
    }
  }

  void _scheduleRevalidate() {
    _debounce?.cancel();
    _debounce = Timer(kStorefrontSyncDebounce, () {
      unawaited(revalidateActive(force: true));
    });
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
  }
}

final storefrontSyncProvider = Provider<StorefrontSync>((Ref ref) {
  final StorefrontSync sync = StorefrontSync(ref);
  ref.onDispose(sync.dispose);
  return sync;
});

Future<void> handleSectionSocketEvent(WidgetRef ref, Map data) async {
  ref
      .read(storefrontSyncProvider)
      .onSectionEvent(Map<String, dynamic>.from(data));
}

Future<void> refreshSectionManifest(WidgetRef ref, String tabKey) async {
  final StorefrontSync sync = ref.read(storefrontSyncProvider);
  final String storeKey = ref.read(storefrontScopeProvider).storeKey;
  markSectionsStale(storeKey: storeKey, tabKey: tabKey);
  await sync.revalidateActive(force: true);
}

// ─── Prefetch ────────────────────────────────────────────────────────────────

/// Warms the tabs a customer is most likely to open next, once the active tab
/// has been stable for [kPrefetchSettleDelay]. One request at a time, and torn
/// down (aborting anything in flight) the moment the active tab or scope
/// changes — so rapid tab switching never queues prefetches ahead of the tab
/// actually being loaded.
const Duration kPrefetchSettleDelay = Duration(milliseconds: 450);
const int _prefetchLimit = 3;

final storefrontPrefetchProvider = Provider<void>((Ref ref) {
  final SectionScopeKey active = ref.watch(activeSectionKeyProvider);
  final List<TabThemeEntry>? tabs = ref.watch(
    tabThemesSnapshotProvider.select((TabThemesResponse? r) => r?.tabs),
  );
  if (tabs == null || tabs.length < 2) {
    return;
  }

  bool cancelled = false;
  final List<LayoutClaim<SectionManifestResponse>> claims =
      <LayoutClaim<SectionManifestResponse>>[];
  final Timer settle = Timer(kPrefetchSettleDelay, () async {
    for (final String tabKey in prefetchOrder(tabs, active.tabKey)) {
      if (cancelled) {
        return;
      }
      final SectionScopeKey key = SectionScopeKey(
        storeKey: active.storeKey,
        shopScope: active.shopScope,
        priceMode: active.priceMode,
        tabKey: tabKey,
      );
      final Held<SectionManifestResponse>? held = peekSections(key);
      if (held != null && held.isFresh) {
        continue;
      }
      final LayoutClaim<SectionManifestResponse> claim = claimSections(key);
      claims.add(claim);
      final FetchOutcome<SectionManifestResponse> outcome = await claim.result;
      if (cancelled) {
        return;
      }
      final SectionManifestResponse? data = outcome.held?.data;
      if (data != null && outcome.status == FetchStatus.updated) {
        unawaited(ThemeAssetWarmer.warmSectionManifest(data));
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  });
  ref.onDispose(() {
    cancelled = true;
    settle.cancel();
    for (final LayoutClaim<SectionManifestResponse> claim in claims) {
      claim.release();
    }
  });
});

/// Tabs to warm, nearest first: the neighbours of [activeTabKey] (right before
/// left, then two steps out), then the store's default tab. Capped.
List<String> prefetchOrder(List<TabThemeEntry> tabs, String activeTabKey) {
  final int index =
      tabs.indexWhere((TabThemeEntry tab) => tab.tabKey == activeTabKey);
  final List<String> ordered = <String>[];
  void add(int i) {
    if (i < 0 || i >= tabs.length) {
      return;
    }
    final String key = tabs[i].tabKey;
    if (key != activeTabKey && !ordered.contains(key)) {
      ordered.add(key);
    }
  }

  if (index >= 0) {
    add(index + 1);
    add(index - 1);
    add(index + 2);
    add(index - 2);
  }
  final String defaultKey = resolveDefaultTab(tabs).tabKey;
  if (defaultKey != activeTabKey && !ordered.contains(defaultKey)) {
    ordered.add(defaultKey);
  }
  return ordered.take(_prefetchLimit).toList(growable: false);
}

String? _readString(dynamic value) {
  if (value == null) {
    return null;
  }
  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}
