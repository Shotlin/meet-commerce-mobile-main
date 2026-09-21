import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/network/api_interceptor.dart';
import 'package:bakaloo_flutter_app/core/network/app_availability_provider.dart';
import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
import 'package:bakaloo_flutter_app/core/storage/secure_storage_service.dart';
import 'package:bakaloo_flutter_app/core/storefront/layout_disk_store.dart';
import 'package:bakaloo_flutter_app/core/storefront/layout_keys.dart';
import 'package:bakaloo_flutter_app/core/storefront/layout_repository.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_model.dart';
import 'package:bakaloo_flutter_app/core/theme/theme_asset_warmer.dart';

/// Layout requests are cheap, cacheable GETs; failing fast beats a long
/// spinner because the last known content stays on screen while we retry.
Dio buildStorefrontDio() {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
    ),
  );
  dio.interceptors.add(ApiInterceptor(SecureStorageService()));
  return dio;
}

/// Dedicated client for layout content. Overridden in tests.
final Provider<Dio> storefrontDioProvider =
    Provider<Dio>((Ref ref) => buildStorefrontDio());

/// Reports layout-load outcomes to the app-wide availability state (the
/// offline / service-unavailable screens). Overridden in tests.
class LayoutHealthSink {
  const LayoutHealthSink({required this.onHealthy, required this.onUnavailable});

  final VoidCallback onHealthy;
  final VoidCallback onUnavailable;
}

final Provider<LayoutHealthSink> layoutHealthSinkProvider =
    Provider<LayoutHealthSink>((Ref ref) {
  return LayoutHealthSink(
    onHealthy: () {
      try {
        ref.read(appAvailabilityProvider.notifier).reportHealthy();
      } catch (_) {}
    },
    onUnavailable: () {
      try {
        ref.read(appAvailabilityProvider.notifier).reportServiceUnavailable();
      } catch (_) {}
    },
  );
});

/// Persistent layer under the repository. Overridden in widget tests, where
/// real file I/O cannot complete inside the fake-async zone.
final Provider<LayoutDiskStore> layoutDiskStoreProvider =
    Provider<LayoutDiskStore>((Ref ref) => const LayoutDiskStore());

/// The single layout repository for the process. Persisted caches being wiped
/// (schema bump, user change) drops its in-memory copies too.
final Provider<StorefrontLayoutRepository> storefrontLayoutRepositoryProvider =
    Provider<StorefrontLayoutRepository>((Ref ref) {
  final StorefrontLayoutRepository repository = StorefrontLayoutRepository(
    dio: ref.watch(storefrontDioProvider),
    disk: ref.watch(layoutDiskStoreProvider),
  );
  void onCachesCleared() => repository.clearMemory();
  AppCacheManager.layoutCacheEpoch.addListener(onCachesCleared);
  ref.onDispose(() {
    AppCacheManager.layoutCacheEpoch.removeListener(onCachesCleared);
    repository.dispose();
  });
  return repository;
});

class LayoutUnavailableException implements Exception {
  const LayoutUnavailableException([this.message = 'Layout unavailable']);

  final String message;

  @override
  String toString() => 'LayoutUnavailableException: $message';
}

/// Holds one theme manifest, keyed by [key] (store + shop scope).
///
/// Instant when content is held: `build` RETURNS the cached value synchronously
/// (an `AsyncData` on the first frame, never a loading flash) and revalidates in
/// the background. A revalidation that finds nothing new changes nothing; one
/// that fails keeps the current content.
class TabThemesController extends AsyncNotifier<TabThemesResponse> {
  TabThemesController(this.key);

  final ThemeKey key;

  LayoutHandle<TabThemesResponse>? _handle;
  bool _loadingFirst = false;

  StorefrontLayoutRepository get _repo =>
      ref.read(storefrontLayoutRepositoryProvider);
  LayoutHealthSink get _health => ref.read(layoutHealthSinkProvider);

  @override
  FutureOr<TabThemesResponse> build() {
    final StorefrontLayoutRepository repo = _repo;
    final StreamSubscription<LayoutChange> subscription =
        repo.changes.listen((LayoutChange change) {
      if (change.themeKey != key || _loadingFirst || !ref.mounted) {
        return;
      }
      final LayoutSnapshot<TabThemesResponse>? snapshot = repo.peekTheme(key);
      if (snapshot != null) {
        _warm(snapshot.data);
        state = AsyncData<TabThemesResponse>(snapshot.data);
      }
    });
    ref.onDispose(() {
      subscription.cancel();
      _handle?.cancel();
    });

    final LayoutSnapshot<TabThemesResponse>? cached = repo.peekTheme(key);
    if (cached != null) {
      _warm(cached.data);
      if (!repo.isFresh(cached)) {
        scheduleMicrotask(() => unawaited(refresh(force: false)));
      }
      return cached.data;
    }
    return _firstLoad();
  }

  Future<TabThemesResponse> _firstLoad() async {
    _loadingFirst = true;
    try {
      final LayoutHandle<TabThemesResponse> handle =
          _repo.revalidateTheme(key);
      _handle = handle;
      final LayoutFetchResult<TabThemesResponse> result = await handle.result;
      final LayoutSnapshot<TabThemesResponse>? snapshot = result.snapshot;
      if (snapshot != null) {
        _health.onHealthy();
        _warm(snapshot.data);
        return snapshot.data;
      }
      if (result.status != LayoutFetchStatus.cancelled) {
        _health.onUnavailable();
      }
      throw result.error ?? const LayoutUnavailableException();
    } finally {
      _loadingFirst = false;
    }
  }

  /// Revalidates now. With [force] false a fresh snapshot is left alone.
  Future<void> refresh({bool force = true}) async {
    if (!ref.mounted || _loadingFirst) {
      return;
    }
    final LayoutSnapshot<TabThemesResponse>? current = _repo.peekTheme(key);
    if (!force && current != null && _repo.isFresh(current)) {
      return;
    }
    final LayoutHandle<TabThemesResponse>? previous = _handle;
    final LayoutHandle<TabThemesResponse> handle = _repo.revalidateTheme(key);
    _handle = handle;
    previous?.cancel();
    final LayoutFetchResult<TabThemesResponse> result = await handle.result;
    if (!ref.mounted) {
      return;
    }
    if (result.snapshot != null) {
      _health.onHealthy();
    } else if (result.status == LayoutFetchStatus.unavailable &&
        !state.hasValue) {
      _health.onUnavailable();
      state = AsyncError<TabThemesResponse>(
        result.error ?? const LayoutUnavailableException(),
        StackTrace.current,
      );
    }
  }

  /// User-initiated retry after a failed first load.
  Future<void> retry() async {
    if (!state.hasValue) {
      state = const AsyncLoading<TabThemesResponse>();
    }
    await refresh();
  }

  void _warm(TabThemesResponse response) =>
      unawaited(ThemeAssetWarmer.warmAssets(response));
}

final tabThemesControllerProvider = AsyncNotifierProvider.autoDispose
        .family<TabThemesController, TabThemesResponse, ThemeKey>(
  TabThemesController.new,
  retry: (int _, Object __) => null,
);

/// Holds one section manifest, keyed by [key] (store + shop scope + price mode
/// + tab). Same instant/SWR contract as [TabThemesController].
class SectionManifestController extends AsyncNotifier<SectionManifestResponse> {
  SectionManifestController(this.key);

  final SectionKey key;

  LayoutHandle<SectionManifestResponse>? _handle;
  bool _loadingFirst = false;

  StorefrontLayoutRepository get _repo =>
      ref.read(storefrontLayoutRepositoryProvider);
  LayoutHealthSink get _health => ref.read(layoutHealthSinkProvider);

  @override
  FutureOr<SectionManifestResponse> build() {
    final StorefrontLayoutRepository repo = _repo;
    final StreamSubscription<LayoutChange> subscription =
        repo.changes.listen((LayoutChange change) {
      if (change.sectionKey != key || _loadingFirst || !ref.mounted) {
        return;
      }
      final LayoutSnapshot<SectionManifestResponse>? snapshot =
          repo.peekSections(key);
      if (snapshot != null) {
        _warm(snapshot.data);
        state = AsyncData<SectionManifestResponse>(snapshot.data);
      }
    });
    ref.onDispose(() {
      subscription.cancel();
      _handle?.cancel();
    });

    final LayoutSnapshot<SectionManifestResponse>? cached =
        repo.peekSections(key);
    if (cached != null) {
      _warm(cached.data);
      if (!repo.isFresh(cached)) {
        scheduleMicrotask(() => unawaited(refresh(force: false)));
      }
      return cached.data;
    }
    return _firstLoad();
  }

  Future<SectionManifestResponse> _firstLoad() async {
    _loadingFirst = true;
    try {
      final LayoutHandle<SectionManifestResponse> handle =
          _repo.revalidateSections(key);
      _handle = handle;
      final LayoutFetchResult<SectionManifestResponse> result =
          await handle.result;
      final LayoutSnapshot<SectionManifestResponse>? snapshot =
          result.snapshot;
      if (snapshot != null) {
        _health.onHealthy();
        _warm(snapshot.data);
        return snapshot.data;
      }
      throw result.error ?? const LayoutUnavailableException();
    } finally {
      _loadingFirst = false;
    }
  }

  Future<void> refresh({bool force = true}) async {
    if (!ref.mounted || _loadingFirst) {
      return;
    }
    final LayoutSnapshot<SectionManifestResponse>? current =
        _repo.peekSections(key);
    if (!force && current != null && _repo.isFresh(current)) {
      return;
    }
    final LayoutHandle<SectionManifestResponse>? previous = _handle;
    final LayoutHandle<SectionManifestResponse> handle =
        _repo.revalidateSections(key);
    _handle = handle;
    previous?.cancel();
    final LayoutFetchResult<SectionManifestResponse> result =
        await handle.result;
    if (!ref.mounted) {
      return;
    }
    if (result.snapshot != null) {
      _health.onHealthy();
    } else if (result.status == LayoutFetchStatus.unavailable &&
        !state.hasValue) {
      state = AsyncError<SectionManifestResponse>(
        result.error ?? const LayoutUnavailableException(),
        StackTrace.current,
      );
    }
  }

  Future<void> retry() async {
    if (!state.hasValue) {
      state = const AsyncLoading<SectionManifestResponse>();
    }
    await refresh();
  }

  void _warm(SectionManifestResponse response) =>
      unawaited(ThemeAssetWarmer.warmSectionManifest(response));
}

final sectionManifestControllerProvider = AsyncNotifierProvider.autoDispose
        .family<SectionManifestController, SectionManifestResponse, SectionKey>(
  SectionManifestController.new,
  retry: (int _, Object __) => null,
);
