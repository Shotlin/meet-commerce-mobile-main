import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/storefront/layout_disk_store.dart';
import 'package:bakaloo_flutter_app/core/storefront/layout_keys.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_model.dart';

/// A parsed layout payload plus the bookkeeping needed to revalidate it.
@immutable
class LayoutSnapshot<T> {
  const LayoutSnapshot({
    required this.data,
    required this.raw,
    required this.fetchedAt,
    this.etag,
  });

  final T data;

  /// The server's `data` object, JSON-encoded as received. Compared on
  /// revalidation so an unchanged payload never produces a UI update.
  final String raw;
  final DateTime fetchedAt;
  final String? etag;

  LayoutSnapshot<T> withFetchedAt(DateTime at) =>
      LayoutSnapshot<T>(data: data, raw: raw, fetchedAt: at, etag: etag);
}

enum LayoutFetchStatus {
  /// New content was received (and committed unless the caller deferred it).
  updated,

  /// The server confirmed the held snapshot is still current.
  notModified,

  /// No usable response (offline, 5xx, malformed). Held data is untouched.
  unavailable,

  /// The request was cancelled because nobody needed it any more.
  cancelled,
}

/// Outcome of one revalidation.
class LayoutFetchResult<T> {
  const LayoutFetchResult._(
    this.status, {
    this.snapshot,
    this.error,
    void Function()? commit,
  }) : _commit = commit;

  final LayoutFetchStatus status;

  /// Best snapshot for the key after this fetch (the new one when
  /// [LayoutFetchStatus.updated]).
  final LayoutSnapshot<T>? snapshot;
  final Object? error;
  final void Function()? _commit;

  /// Applies a deferred result (memory + disk + change notification).
  /// Idempotent, and a no-op when there is nothing to apply.
  void commit() => _commit?.call();
}

/// A live claim on a (possibly shared) network request. Call [cancel] when
/// the result is no longer needed; the request is aborted once every claimant
/// has cancelled.
class LayoutHandle<T> {
  LayoutHandle._(this.result, this._release);

  factory LayoutHandle.completed(LayoutFetchResult<T> value) =>
      LayoutHandle<T>._(Future<LayoutFetchResult<T>>.value(value), null);

  final Future<LayoutFetchResult<T>> result;
  final void Function()? _release;
  bool _released = false;

  void cancel() {
    if (_released) {
      return;
    }
    _released = true;
    _release?.call();
  }
}

/// Emitted synchronously after a commit that changed content.
@immutable
class LayoutChange {
  const LayoutChange.theme(ThemeKey this.themeKey) : sectionKey = null;
  const LayoutChange.sections(SectionKey this.sectionKey) : themeKey = null;

  final ThemeKey? themeKey;
  final SectionKey? sectionKey;
}

class _Flight<T> {
  _Flight(this.token);

  final CancelToken token;
  late final Future<LayoutFetchResult<T>> future;
  int claimants = 0;
}

class _Lru<T> {
  _Lru(this.capacity);

  final int capacity;
  final LinkedHashMap<String, T> _map = LinkedHashMap<String, T>();

  T? get(String key) {
    final T? value = _map.remove(key);
    if (value != null) {
      _map[key] = value;
    }
    return value;
  }

  void put(String key, T value) {
    _map.remove(key);
    _map[key] = value;
    while (_map.length > capacity) {
      _map.remove(_map.keys.first);
    }
  }

  Iterable<MapEntry<String, T>> get entries => _map.entries.toList();

  void clear() => _map.clear();
}

/// The single reader/writer of storefront layout content (theme manifests and
/// section manifests).
///
/// Guarantees:
///  * every request is described by an immutable key captured at START and the
///    result can only ever be written under that key;
///  * identical in-flight requests are shared, and a shared request is aborted
///    only when its last claimant cancels (latest-selection-wins without
///    starving another caller);
///  * an unchanged payload (same ETag / same bytes) never produces a
///    [LayoutChange], so revalidation can never cause a rebuild loop;
///  * a failed fetch never replaces or blanks held content.
class StorefrontLayoutRepository {
  StorefrontLayoutRepository({
    required Dio dio,
    LayoutDiskStore disk = const LayoutDiskStore(),
    DateTime Function()? now,
    this.staleAfter = const Duration(seconds: 45),
    int themeCapacity = 8,
    int sectionCapacity = 48,
  })  : _dio = dio,
        _disk = disk,
        _now = now ?? DateTime.now,
        _themes = _Lru<LayoutSnapshot<TabThemesResponse>>(themeCapacity),
        _sections =
            _Lru<LayoutSnapshot<SectionManifestResponse>>(sectionCapacity);

  final Dio _dio;
  final LayoutDiskStore _disk;
  final DateTime Function() _now;

  /// Snapshots younger than this are served without contacting the server.
  final Duration staleAfter;

  final _Lru<LayoutSnapshot<TabThemesResponse>> _themes;
  final _Lru<LayoutSnapshot<SectionManifestResponse>> _sections;
  final Map<String, _Flight<TabThemesResponse>> _themeFlights =
      <String, _Flight<TabThemesResponse>>{};
  final Map<String, _Flight<SectionManifestResponse>> _sectionFlights =
      <String, _Flight<SectionManifestResponse>>{};
  final StreamController<LayoutChange> _changes =
      StreamController<LayoutChange>.broadcast(sync: true);

  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  Stream<LayoutChange> get changes => _changes.stream;

  // ─── Reads ────────────────────────────────────────────────────────────────

  /// Memory, then disk. A snapshot restored from disk is treated as stale so
  /// it is revalidated (cheaply, via ETag) on first use in this process.
  LayoutSnapshot<TabThemesResponse>? peekTheme(ThemeKey key) {
    final LayoutSnapshot<TabThemesResponse>? cached = _themes.get(key.id);
    if (cached != null) {
      return cached;
    }
    final StoredLayout? stored = _disk.readTheme(key);
    if (stored == null) {
      return null;
    }
    try {
      final Map<String, dynamic> map = _decodeMap(stored.raw);
      final TabThemesResponse parsed =
          TabThemesResponse.fromJson(_withEtag(map, stored.etag));
      final LayoutSnapshot<TabThemesResponse> snapshot =
          LayoutSnapshot<TabThemesResponse>(
        data: parsed,
        raw: stored.raw,
        fetchedAt: _epoch,
        etag: stored.etag,
      );
      _themes.put(key.id, snapshot);
      return snapshot;
    } catch (error) {
      debugPrint('[Layout] discarded unreadable theme cache $key: $error');
      return null;
    }
  }

  LayoutSnapshot<SectionManifestResponse>? peekSections(SectionKey key) {
    final LayoutSnapshot<SectionManifestResponse>? cached =
        _sections.get(key.id);
    if (cached != null) {
      return cached;
    }
    final StoredLayout? stored = _disk.readSections(key);
    if (stored == null) {
      return null;
    }
    try {
      final Map<String, dynamic> map = _decodeMap(stored.raw);
      final SectionManifestResponse parsed =
          SectionManifestResponse.fromJson(_withEtag(map, stored.etag));
      final LayoutSnapshot<SectionManifestResponse> snapshot =
          LayoutSnapshot<SectionManifestResponse>(
        data: parsed,
        raw: stored.raw,
        fetchedAt: _epoch,
        etag: stored.etag,
      );
      _sections.put(key.id, snapshot);
      return snapshot;
    } catch (error) {
      debugPrint('[Layout] discarded unreadable manifest cache $key: $error');
      return null;
    }
  }

  bool isFresh(LayoutSnapshot<Object?> snapshot) =>
      _now().difference(snapshot.fetchedAt) < staleAfter;

  // ─── Revalidation ─────────────────────────────────────────────────────────

  /// Fetches (or joins an in-flight fetch of) the theme manifest for [key].
  ///
  /// With [deferCommit] the new content is held until `result.commit()` so the
  /// caller can apply it together with other resources in one frame.
  LayoutHandle<TabThemesResponse> revalidateTheme(
    ThemeKey key, {
    bool deferCommit = false,
  }) {
    return _start<TabThemesResponse>(
      flights: _themeFlights,
      id: key.id,
      deferCommit: deferCommit,
      run: (CancelToken token) => _fetch<TabThemesResponse>(
        path: ApiConstants.tabThemes,
        query: <String, dynamic>{'store_key': key.storeKey},
        current: _themes.get(key.id) ?? peekTheme(key),
        token: token,
        parse: TabThemesResponse.fromJson,
        apply: (
          LayoutSnapshot<TabThemesResponse> next, {
          required bool changed,
        }) {
          _themes.put(key.id, next);
          unawaited(
            _disk.writeTheme(
              key,
              StoredLayout(raw: next.raw, savedAt: next.fetchedAt, etag: next.etag),
            ),
          );
          if (changed) {
            _changes.add(LayoutChange.theme(key));
          }
        },
      ),
    );
  }

  /// Section-manifest counterpart of [revalidateTheme].
  LayoutHandle<SectionManifestResponse> revalidateSections(
    SectionKey key, {
    bool deferCommit = false,
  }) {
    return _start<SectionManifestResponse>(
      flights: _sectionFlights,
      id: key.id,
      deferCommit: deferCommit,
      run: (CancelToken token) => _fetch<SectionManifestResponse>(
        path: '${ApiConstants.sectionManifest}/${key.tabKey}/sections',
        // priceMode is sent explicitly (not left to the interceptor) so the
        // request always matches the key it will be stored under, even if the
        // customer flips B2C/B2B while it is in flight.
        query: <String, dynamic>{
          'store_key': key.storeKey,
          'priceMode': key.priceMode,
        },
        current: _sections.get(key.id) ?? peekSections(key),
        token: token,
        parse: SectionManifestResponse.fromJson,
        apply: (
          LayoutSnapshot<SectionManifestResponse> next, {
          required bool changed,
        }) {
          _sections.put(key.id, next);
          unawaited(
            _disk.writeSections(
              key,
              StoredLayout(raw: next.raw, savedAt: next.fetchedAt, etag: next.etag),
            ),
          );
          if (changed) {
            _changes.add(LayoutChange.sections(key));
          }
        },
      ),
    );
  }

  LayoutHandle<T> _start<T>({
    required Map<String, _Flight<T>> flights,
    required String id,
    required bool deferCommit,
    required Future<LayoutFetchResult<T>> Function(CancelToken token) run,
  }) {
    _Flight<T>? flight = flights[id];
    if (flight == null || flight.token.isCancelled) {
      final _Flight<T> created = _Flight<T>(CancelToken());
      flights[id] = created;
      created.future = run(created.token).whenComplete(() {
        if (identical(flights[id], created)) {
          flights.remove(id);
        }
      });
      flight = created;
    }
    final _Flight<T> joined = flight;
    joined.claimants++;
    final Future<LayoutFetchResult<T>> result =
        joined.future.then((LayoutFetchResult<T> value) {
      if (!deferCommit) {
        value.commit();
      }
      return value;
    });
    return LayoutHandle<T>._(result, () {
      joined.claimants--;
      if (joined.claimants <= 0 && !joined.token.isCancelled) {
        joined.token.cancel('no longer needed');
      }
    });
  }

  Future<LayoutFetchResult<T>> _fetch<T>({
    required String path,
    required Map<String, dynamic> query,
    required LayoutSnapshot<T>? current,
    required CancelToken token,
    required T Function(Map<String, dynamic>) parse,
    required void Function(LayoutSnapshot<T> next, {required bool changed})
        apply,
  }) async {
    try {
      final String? heldEtag = current?.etag;
      final Response<dynamic> response = await _dio.get<dynamic>(
        path,
        queryParameters: query,
        cancelToken: token,
        options: Options(
          headers: <String, dynamic>{
            if (heldEtag != null && heldEtag.isNotEmpty)
              'If-None-Match': heldEtag,
          },
          validateStatus: (int? status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 304 && current != null) {
        return _touch<T>(current, apply);
      }

      final dynamic payload = response.data;
      if (payload is! Map ||
          payload['success'] != true ||
          payload['data'] is! Map) {
        return LayoutFetchResult<T>._(
          LayoutFetchStatus.unavailable,
          snapshot: current,
          error: StateError(
            'Unexpected layout response (${response.statusCode}) for $path',
          ),
        );
      }

      final Map<String, dynamic> dataMap =
          Map<String, dynamic>.from(payload['data'] as Map);
      final String? etag = response.headers.value('etag');
      final String raw = jsonEncode(dataMap);

      if (current != null && current.raw == raw) {
        // Same bytes: refresh freshness, keep the existing (identical) object.
        return _touch<T>(current, apply, etag: etag ?? current.etag);
      }

      final LayoutSnapshot<T> next = LayoutSnapshot<T>(
        data: parse(_withEtag(dataMap, etag)),
        raw: raw,
        fetchedAt: _now(),
        etag: etag,
      );
      bool committed = false;
      return LayoutFetchResult<T>._(
        LayoutFetchStatus.updated,
        snapshot: next,
        commit: () {
          if (committed) {
            return;
          }
          committed = true;
          apply(next, changed: true);
        },
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        return LayoutFetchResult<T>._(LayoutFetchStatus.cancelled);
      }
      return LayoutFetchResult<T>._(
        LayoutFetchStatus.unavailable,
        snapshot: current,
        error: error,
      );
    } catch (error) {
      return LayoutFetchResult<T>._(
        LayoutFetchStatus.unavailable,
        snapshot: current,
        error: error,
      );
    }
  }

  LayoutFetchResult<T> _touch<T>(
    LayoutSnapshot<T> current,
    void Function(LayoutSnapshot<T> next, {required bool changed}) apply, {
    String? etag,
  }) {
    final LayoutSnapshot<T> refreshed = LayoutSnapshot<T>(
      data: current.data,
      raw: current.raw,
      fetchedAt: _now(),
      etag: etag ?? current.etag,
    );
    bool committed = false;
    return LayoutFetchResult<T>._(
      LayoutFetchStatus.notModified,
      snapshot: refreshed,
      commit: () {
        if (committed) {
          return;
        }
        committed = true;
        apply(refreshed, changed: false);
      },
    );
  }

  // ─── Invalidation ─────────────────────────────────────────────────────────

  /// Marks held content stale WITHOUT dropping it (so it keeps rendering) so
  /// the next use revalidates. [storeKey]/[tabKey] narrow what is affected;
  /// every shop scope and price mode of the match is marked, since a dashboard
  /// change is not shop-addressed.
  void markStale({String? storeKey, String? tabKey}) {
    // Keys are `store|scope` (theme) and `store|scope|mode|tab` (section) —
    // matched on the KEY, never on payload fields, so a payload that omits or
    // mislabels them cannot dodge invalidation.
    for (final MapEntry<String, LayoutSnapshot<TabThemesResponse>> entry
        in _themes.entries) {
      if (storeKey == null || entry.key.split('|').first == storeKey) {
        _themes.put(entry.key, entry.value.withFetchedAt(_epoch));
      }
    }
    for (final MapEntry<String, LayoutSnapshot<SectionManifestResponse>> entry
        in _sections.entries) {
      final List<String> parts = entry.key.split('|');
      if ((storeKey == null || parts.first == storeKey) &&
          (tabKey == null || parts.last == tabKey)) {
        _sections.put(entry.key, entry.value.withFetchedAt(_epoch));
      }
    }
  }

  /// Drops every in-memory snapshot (persisted caches were wiped).
  void clearMemory() {
    _themes.clear();
    _sections.clear();
  }

  void dispose() {
    for (final _Flight<Object?> flight in <_Flight<Object?>>[
      ..._themeFlights.values,
      ..._sectionFlights.values,
    ]) {
      if (!flight.token.isCancelled) {
        flight.token.cancel('repository disposed');
      }
    }
    _changes.close();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static Map<String, dynamic> _decodeMap(String raw) {
    final dynamic decoded = jsonDecode(raw);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw const FormatException('layout payload is not an object');
  }

  static Map<String, dynamic> _withEtag(
    Map<String, dynamic> map,
    String? etag,
  ) {
    if (etag == null || etag.isEmpty) {
      return map;
    }
    return <String, dynamic>{...map, 'etag': etag};
  }
}
