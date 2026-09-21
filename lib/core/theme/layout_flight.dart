import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';

/// Shared plumbing for the three Theme-Builder resources (theme manifest,
/// section manifest, tab-home content) that `remote_theme_provider.dart` and
/// `section_manifest_provider.dart` fetch and cache:
///
///  * a held (memory) snapshot with the bookkeeping to revalidate it,
///  * ref-counted request "flights" so identical requests are shared and a
///    request is aborted only when its LAST claimant lets go (latest selection
///    wins without starving anybody else),
///  * an ETag/bytes comparison so an unchanged response never notifies,
///  * a per-resource change signal (no global epoch that rebuilds everything),
///  * a swappable persistence seam.
///
/// Every resource is addressed by an immutable key captured when the request
/// STARTS; a response can only be written under the key it was requested for.

/// Content younger than this is served without contacting the server.
const Duration kLayoutStaleAfter = Duration(seconds: 45);

final DateTime kLayoutEpoch = DateTime.fromMillisecondsSinceEpoch(0);

@visibleForTesting
DateTime Function() layoutNow = DateTime.now;

/// A parsed payload plus what is needed to revalidate it.
@immutable
class Held<T> {
  const Held({
    required this.data,
    required this.raw,
    required this.fetchedAt,
    this.etag,
  });

  final T data;

  /// The server's `data` object, JSON-encoded as received.
  final String raw;
  final DateTime fetchedAt;
  final String? etag;

  bool get isFresh => layoutNow().difference(fetchedAt) < kLayoutStaleAfter;

  Held<T> withFetchedAt(DateTime at) =>
      Held<T>(data: data, raw: raw, fetchedAt: at, etag: etag);
}

enum FetchStatus { updated, notModified, unavailable, cancelled }

class FetchOutcome<T> {
  const FetchOutcome._(
    this.status, {
    this.held,
    this.error,
    void Function()? commit,
  }) : _commit = commit;

  final FetchStatus status;

  /// Best snapshot for the key after this fetch (the new one when updated).
  final Held<T>? held;
  final Object? error;
  final void Function()? _commit;

  /// Applies a deferred result (memory + disk + change signal). Idempotent.
  void commit() => _commit?.call();
}

/// A claim on a (possibly shared) request. Call [release] when the result is
/// no longer needed; the request is aborted once every claimant released.
class LayoutClaim<T> {
  LayoutClaim._(this.result, this._release);

  final Future<FetchOutcome<T>> result;
  final void Function()? _release;
  bool _released = false;

  void release() {
    if (_released) {
      return;
    }
    _released = true;
    _release?.call();
  }
}

class _Flight<T> {
  _Flight(this.token);

  final CancelToken token;
  late final Future<FetchOutcome<T>> future;
  int claimants = 0;
}

class FlightBoard<T> {
  final Map<String, _Flight<T>> _flights = <String, _Flight<T>>{};

  LayoutClaim<T> claim(
    String id,
    Future<FetchOutcome<T>> Function(CancelToken token) run, {
    bool deferCommit = false,
  }) {
    _Flight<T>? flight = _flights[id];
    if (flight == null || flight.token.isCancelled) {
      final _Flight<T> created = _Flight<T>(CancelToken());
      _flights[id] = created;
      created.future = run(created.token).whenComplete(() {
        if (identical(_flights[id], created)) {
          _flights.remove(id);
        }
      });
      flight = created;
    }
    final _Flight<T> joined = flight;
    joined.claimants++;
    final Future<FetchOutcome<T>> result =
        joined.future.then((FetchOutcome<T> outcome) {
      if (!deferCommit) {
        outcome.commit();
      }
      return outcome;
    });
    return LayoutClaim<T>._(result, () {
      joined.claimants--;
      if (joined.claimants <= 0 && !joined.token.isCancelled) {
        joined.token.cancel('no longer needed');
      }
    });
  }

  void cancelAll() {
    for (final _Flight<T> f in _flights.values) {
      if (!f.token.isCancelled) {
        f.token.cancel('reset');
      }
    }
    _flights.clear();
  }
}

/// Bounded LRU of held snapshots.
class LayoutMemory<T> {
  LayoutMemory(this.capacity) {
    _registry.add(clear);
  }

  final int capacity;
  final LinkedHashMap<String, Held<T>> _map = LinkedHashMap<String, Held<T>>();

  Held<T>? get(String id) {
    _ensureCacheEpochListener();
    final Held<T>? value = _map.remove(id);
    if (value != null) {
      _map[id] = value;
    }
    return value;
  }

  void put(String id, Held<T> value) {
    _ensureCacheEpochListener();
    _map.remove(id);
    _map[id] = value;
    while (_map.length > capacity) {
      _map.remove(_map.keys.first);
    }
  }

  /// Marks entries stale WITHOUT dropping them (they keep rendering), where
  /// [matches] receives the entry id.
  void markStale(bool Function(String id) matches) {
    for (final MapEntry<String, Held<T>> e
        in _map.entries.toList(growable: false)) {
      if (matches(e.key)) {
        _map[e.key] = e.value.withFetchedAt(kLayoutEpoch);
      }
    }
  }

  void clear() => _map.clear();

  static final List<VoidCallback> _registry = <VoidCallback>[];
  static bool _listening = false;

  static void _ensureCacheEpochListener() {
    if (_listening) {
      return;
    }
    _listening = true;
    // Persisted caches wiped (schema bump / different user) ⇒ drop the
    // in-memory copies with them.
    AppCacheManager.layoutCacheEpoch.addListener(() {
      for (final VoidCallback clear in List<VoidCallback>.of(_registry)) {
        clear();
      }
    });
  }
}

enum LayoutBox { theme, sections, tabHome }

/// Where layout payloads persist. Swappable so tests need no real file I/O.
abstract class LayoutPersistence {
  String? read(LayoutBox box, String key);
  Future<void> write(LayoutBox box, String key, String value);
}

class HiveLayoutPersistence implements LayoutPersistence {
  const HiveLayoutPersistence();

  Box<dynamic> _box(LayoutBox box) {
    switch (box) {
      case LayoutBox.sections:
        return HiveService.sectionManifestBox;
      case LayoutBox.theme:
      case LayoutBox.tabHome:
        return HiveService.remoteThemeBox;
    }
  }

  @override
  String? read(LayoutBox box, String key) {
    try {
      final dynamic value = _box(box).get(key);
      return value is String ? value : null;
    } catch (error) {
      debugPrint('[Layout] read failed for $key: $error');
      return null;
    }
  }

  @override
  Future<void> write(LayoutBox box, String key, String value) async {
    try {
      await _box(box).put(key, value);
    } catch (error) {
      debugPrint('[Layout] write failed for $key: $error');
    }
  }
}

/// Where layout payloads persist (replaceable in tests).
LayoutPersistence layoutPersistence = const HiveLayoutPersistence();

/// Emits the change-signal id of a resource AFTER a commit that changed its
/// content. Providers listen for their own id only.
final StreamController<String> layoutChanges =
    StreamController<String>.broadcast(sync: true);

/// Persistent form: `v3\n<savedAtMs>\n<etag>\n<json>`.
String encodeLayoutEnvelope({
  required String raw,
  required DateTime savedAt,
  String? etag,
}) =>
    'v3\n${savedAt.millisecondsSinceEpoch}\n${etag ?? ''}\n$raw';

({String raw, String? etag})? decodeLayoutEnvelope(String? value) {
  if (value == null || !value.startsWith('v3\n')) {
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
  final String etag = value.substring(a + 1, b);
  return (raw: value.substring(b + 1), etag: etag.isEmpty ? null : etag);
}

Map<String, dynamic> decodeLayoutMap(String raw) {
  final dynamic decoded = jsonDecode(raw);
  if (decoded is Map) {
    return Map<String, dynamic>.from(decoded);
  }
  throw const FormatException('layout payload is not an object');
}

Map<String, dynamic> withEtag(Map<String, dynamic> map, String? etag) =>
    (etag == null || etag.isEmpty)
        ? map
        : <String, dynamic>{...map, 'etag': etag};

/// Revalidates one resource over HTTP.
///
/// 304 ⇒ freshness refresh only; identical bytes ⇒ freshness refresh only (no
/// change signal); a failure keeps [current]; cancellation is reported as such.
Future<FetchOutcome<T>> revalidateLayoutResource<T>({
  required Dio dio,
  required String path,
  required Map<String, dynamic> query,
  required Held<T>? current,
  required CancelToken token,
  required T Function(Map<String, dynamic>) parse,
  required void Function(Held<T> next, {required bool changed}) apply,
}) async {
  FetchOutcome<T> touch(String? etag) {
    final Held<T> refreshed = Held<T>(
      data: current!.data,
      raw: current.raw,
      fetchedAt: layoutNow(),
      etag: etag ?? current.etag,
    );
    bool committed = false;
    return FetchOutcome<T>._(
      FetchStatus.notModified,
      held: refreshed,
      commit: () {
        if (!committed) {
          committed = true;
          apply(refreshed, changed: false);
        }
      },
    );
  }

  try {
    final String? heldEtag = current?.etag;
    final Response<dynamic> response = await dio.get<dynamic>(
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
      return touch(null);
    }

    final dynamic payload = response.data;
    if (payload is! Map ||
        payload['success'] != true ||
        payload['data'] is! Map) {
      return FetchOutcome<T>._(
        FetchStatus.unavailable,
        held: current,
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
      return touch(etag);
    }

    final Held<T> next = Held<T>(
      data: parse(withEtag(dataMap, etag)),
      raw: raw,
      fetchedAt: layoutNow(),
      etag: etag,
    );
    bool committed = false;
    return FetchOutcome<T>._(
      FetchStatus.updated,
      held: next,
      commit: () {
        if (!committed) {
          committed = true;
          apply(next, changed: true);
        }
      },
    );
  } on DioException catch (error) {
    if (CancelToken.isCancel(error)) {
      return FetchOutcome<T>._(FetchStatus.cancelled);
    }
    return FetchOutcome<T>._(
      FetchStatus.unavailable,
      held: current,
      error: error,
    );
  } catch (error) {
    return FetchOutcome<T>._(
      FetchStatus.unavailable,
      held: current,
      error: error,
    );
  }
}

class LayoutUnavailableException implements Exception {
  const LayoutUnavailableException([this.message = 'Layout unavailable']);

  final String message;

  @override
  String toString() => 'LayoutUnavailableException: $message';
}
