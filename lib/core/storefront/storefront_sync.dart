import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/storefront/layout_keys.dart';
import 'package:bakaloo_flutter_app/core/storefront/layout_providers.dart';
import 'package:bakaloo_flutter_app/core/storefront/layout_repository.dart';
import 'package:bakaloo_flutter_app/core/storefront/storefront_scope.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_model.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/theme_asset_warmer.dart';

/// How long dashboard events are coalesced before one revalidation runs. A
/// Theme Builder save typically emits several events back to back.
const Duration kStorefrontSyncDebounce = Duration(milliseconds: 350);

/// Background refresh cadence. It revalidates in place (ETag → usually 304);
/// it never clears caches or blanks the screen.
const Duration kStorefrontPeriodicRefresh = Duration(minutes: 5);
const int _scrollIdleThresholdMs = 800;

/// The one place that keeps the visible storefront current:
///  * Socket.IO `theme:update` / `section:update` (coalesced, one refresh),
///  * a scroll-idle-aware periodic revalidation,
///  * lifecycle / pull-to-refresh / retry entry points.
///
/// A refresh fetches the theme AND the active tab's manifest and commits both
/// in the same synchronous block, so the screen moves from the old layout to
/// the new one in a single frame — never old chrome with new sections.
class StorefrontSync {
  StorefrontSync(this._ref);

  final Ref _ref;
  Timer? _debounce;
  Timer? _periodic;
  Timer? _idleWait;
  bool _disposed = false;

  StorefrontLayoutRepository get _repo =>
      _ref.read(storefrontLayoutRepositoryProvider);

  void _start() {
    _periodic = Timer.periodic(kStorefrontPeriodicRefresh, (_) {
      final int now = DateTime.now().millisecondsSinceEpoch;
      if ((now - homeScrollLastEventMs) < _scrollIdleThresholdMs) {
        _deferUntilScrollIdle();
      } else {
        unawaited(revalidateActive(force: true));
      }
    });
  }

  void _deferUntilScrollIdle() {
    if (_idleWait?.isActive ?? false) {
      return;
    }
    final int startedMs = DateTime.now().millisecondsSinceEpoch;
    _idleWait = Timer.periodic(const Duration(milliseconds: 500), (Timer t) {
      final int now = DateTime.now().millisecondsSinceEpoch;
      final bool scrolling =
          (now - homeScrollLastEventMs) < _scrollIdleThresholdMs;
      if (!scrolling || now - startedMs > 120000) {
        t.cancel();
        unawaited(revalidateActive(force: true));
      }
    });
  }

  /// Revalidates the active theme + tab manifest. Commits together.
  ///
  /// With [force] false, content younger than the repository's freshness
  /// window is left alone (no request at all).
  Future<void> revalidateActive({bool force = false}) async {
    if (_disposed) {
      return;
    }
    final StorefrontScope scope = _ref.read(storefrontScopeProvider);
    final String tabKey = _ref.read(activeTabKeyProvider);
    final ThemeKey themeKey = scope.themeKey;
    final SectionKey sectionKey = scope.sectionKey(tabKey);
    final StorefrontLayoutRepository repo = _repo;

    final LayoutSnapshot<TabThemesResponse>? theme = repo.peekTheme(themeKey);
    final LayoutSnapshot<SectionManifestResponse>? sections =
        repo.peekSections(sectionKey);

    final List<LayoutHandle<Object?>> handles = <LayoutHandle<Object?>>[];
    if (force || theme == null || !repo.isFresh(theme)) {
      handles.add(repo.revalidateTheme(themeKey, deferCommit: true));
    }
    if (force || sections == null || !repo.isFresh(sections)) {
      handles.add(repo.revalidateSections(sectionKey, deferCommit: true));
    }
    if (handles.isEmpty) {
      return;
    }

    final List<LayoutFetchResult<Object?>> results =
        await Future.wait<LayoutFetchResult<Object?>>(
      handles.map((LayoutHandle<Object?> h) => h.result),
    );
    if (_disposed) {
      return;
    }
    // One synchronous block => one frame. Riverpod notifies each dependent as
    // its controller applies the change; Flutter coalesces them into a single
    // rebuild.
    for (final LayoutFetchResult<Object?> result in results) {
      result.commit();
    }
  }

  /// Dashboard changed a theme. Marks that storefront's held content stale
  /// (it keeps rendering) and, when it is the visible one, refreshes it.
  void onThemeEvent(Map<String, dynamic> data) {
    final String current = _ref.read(storefrontScopeProvider).storeKey;
    final String storeKey = _readString(data['storeKey'] ?? data['store_key']) ??
        current;
    _repo.markStale(storeKey: storeKey);
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
    _repo.markStale(storeKey: storeKey, tabKey: tabKey);
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

  /// Retry after a failed first load (theme and/or the active manifest).
  Future<void> retryActive() async {
    final StorefrontScope scope = _ref.read(storefrontScopeProvider);
    final SectionKey sectionKey =
        scope.sectionKey(_ref.read(activeTabKeyProvider));
    await Future.wait<void>(<Future<void>>[
      if (!_ref.read(themeReadyProvider))
        _ref.read(tabThemesControllerProvider(scope.themeKey).notifier).retry(),
      _ref.read(sectionManifestControllerProvider(sectionKey).notifier).retry(),
    ]);
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _periodic?.cancel();
    _idleWait?.cancel();
  }
}

/// Keeps [StorefrontSync] alive and wired to the socket streams. Watch/listen
/// to this once from the home screen.
final Provider<StorefrontSync> storefrontSyncProvider =
    Provider<StorefrontSync>((Ref ref) {
  final StorefrontSync sync = StorefrontSync(ref).._start();
  ref.onDispose(sync.dispose);
  ref.listen<AsyncValue<Map<String, dynamic>>>(
    socketThemeUpdateStreamProvider,
    (AsyncValue<Map<String, dynamic>>? _, AsyncValue<Map<String, dynamic>> next) {
      next.whenData(sync.onThemeEvent);
    },
  );
  ref.listen<AsyncValue<Map<String, dynamic>>>(
    socketSectionUpdateStreamProvider,
    (AsyncValue<Map<String, dynamic>>? _, AsyncValue<Map<String, dynamic>> next) {
      next.whenData(sync.onSectionEvent);
    },
  );
  return sync;
});

/// Warms the tabs a customer is most likely to open next, AFTER the active tab
/// has been stable for [settleDelay]. Runs one request at a time, and is torn
/// down (aborting anything in flight) the moment the active tab or scope
/// changes — so rapid tab switching never queues prefetches ahead of the tab
/// actually being loaded.
const Duration kPrefetchSettleDelay = Duration(milliseconds: 450);
const int _prefetchLimit = 3;

final Provider<void> storefrontPrefetchProvider = Provider<void>((Ref ref) {
  final StorefrontLayoutRepository repo =
      ref.watch(storefrontLayoutRepositoryProvider);
  final SectionKey active = ref.watch(activeSectionKeyProvider);
  final List<TabThemeEntry>? tabs = ref.watch(themeTabsProvider);
  if (tabs == null || tabs.length < 2) {
    return;
  }

  bool cancelled = false;
  final List<LayoutHandle<SectionManifestResponse>> handles =
      <LayoutHandle<SectionManifestResponse>>[];
  final Timer settle = Timer(kPrefetchSettleDelay, () async {
    for (final String tabKey in prefetchOrder(tabs, active.tabKey)) {
      if (cancelled) {
        return;
      }
      final SectionKey key = SectionKey(
        storeKey: active.storeKey,
        shopScope: active.shopScope,
        priceMode: active.priceMode,
        tabKey: tabKey,
      );
      final LayoutSnapshot<SectionManifestResponse>? held =
          repo.peekSections(key);
      if (held != null && repo.isFresh(held)) {
        continue;
      }
      final LayoutHandle<SectionManifestResponse> handle =
          repo.revalidateSections(key);
      handles.add(handle);
      final LayoutFetchResult<SectionManifestResponse> result =
          await handle.result;
      if (cancelled) {
        return;
      }
      final SectionManifestResponse? data = result.snapshot?.data;
      if (data != null && result.status == LayoutFetchStatus.updated) {
        unawaited(ThemeAssetWarmer.warmSectionManifest(data));
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  });
  ref.onDispose(() {
    cancelled = true;
    settle.cancel();
    for (final LayoutHandle<SectionManifestResponse> handle in handles) {
      handle.cancel();
    }
  });
});

/// Tabs to warm, nearest first: the neighbours of [activeTabKey] (right before
/// left, then two steps out), then the store's default tab. Capped.
@visibleForTesting
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
