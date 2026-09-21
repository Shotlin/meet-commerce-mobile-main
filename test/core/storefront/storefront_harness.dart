import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';
import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/core/storefront/layout_disk_store.dart';
import 'package:bakaloo_flutter_app/core/storefront/layout_keys.dart';
import 'package:bakaloo_flutter_app/core/storefront/layout_providers.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_provider.dart';

/// One request the fake backend has been asked to serve.
class FakeRequest {
  FakeRequest(this.options, this._completer);

  final RequestOptions options;
  final Completer<ResponseBody> _completer;

  bool cancelled = false;
  bool get done => _completer.isCompleted;

  String get path => options.path;
  Map<String, dynamic> get query => options.queryParameters;
  String? get ifNoneMatch => options.headers['If-None-Match'] as String?;

  bool get isTheme => path == '/theme/tabs';
  String? get tabKey {
    final RegExpMatch? m = RegExp(r'^/theme/tabs/([^/]+)/sections$').firstMatch(path);
    return m?.group(1);
  }

  void respondJson(
    Object body, {
    int status = 200,
    Map<String, List<String>>? headers,
  }) {
    if (_completer.isCompleted) {
      return;
    }
    _completer.complete(
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          ...?headers,
        },
      ),
    );
  }

  void respondNotModified() {
    if (_completer.isCompleted) {
      return;
    }
    _completer.complete(ResponseBody.fromString('', 304));
  }

  void fail() {
    if (_completer.isCompleted) {
      return;
    }
    _completer.completeError(
      DioException.connectionError(
        requestOptions: options,
        reason: 'test network failure',
      ),
    );
  }
}

/// Fake backend: every request is recorded and held until the test answers it
/// (or answered immediately by [autoRespond]). Holding requests is what lets a
/// test deliver responses out of order.
class FakeStorefrontAdapter implements HttpClientAdapter {
  final List<FakeRequest> requests = <FakeRequest>[];

  /// When set, answers each request immediately instead of holding it.
  void Function(FakeRequest request)? autoRespond;

  Iterable<FakeRequest> get pending =>
      requests.where((FakeRequest r) => !r.done && !r.cancelled);

  int count(bool Function(FakeRequest r) test) => requests.where(test).length;

  FakeRequest lastWhere(bool Function(FakeRequest r) test) =>
      requests.lastWhere(test);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final Completer<ResponseBody> completer = Completer<ResponseBody>();
    final FakeRequest request = FakeRequest(options, completer);
    requests.add(request);
    cancelFuture?.then((_) {
      request.cancelled = true;
      if (!completer.isCompleted) {
        completer.completeError(
          DioException.requestCancelled(
            requestOptions: options,
            reason: 'cancelled',
          ),
        );
      }
    });
    autoRespond?.call(request);
    return completer.future;
  }

  @override
  void close({bool force = false}) {}
}

// ─── Payload builders ────────────────────────────────────────────────────────

Map<String, dynamic> themePayload({
  required String storeKey,
  String? shopId,
  required List<String> tabKeys,
  required String topBarColor,
  String defaultTab = 'all',
}) {
  int order = 0;
  return <String, dynamic>{
    'success': true,
    'message': 'Tab themes',
    'data': <String, dynamic>{
      'store_key': storeKey,
      'shop_id': shopId,
      'delivery_eta_minutes': 30,
      'tabs': <Map<String, dynamic>>[
        for (final String key in tabKeys)
          <String, dynamic>{
            'tab_id': 'tab-$key',
            'store_key': storeKey,
            'tab_key': key,
            'tab_label': key[0].toUpperCase() + key.substring(1),
            'tab_order': order++,
            'is_default': key == defaultTab,
            'variant': 'A',
            'theme_data': <String, dynamic>{
              'sections': <String, dynamic>{
                'topBar': <String, dynamic>{
                  'backgroundColor': topBarColor,
                  'textColor': '#FFFFFF',
                },
              },
            },
          },
      ],
    },
  };
}

Map<String, dynamic> sectionsPayload({
  required String storeKey,
  required String tabKey,
  required String title,
  List<Map<String, dynamic>> products = const <Map<String, dynamic>>[],
}) {
  return <String, dynamic>{
    'success': true,
    'message': 'Section manifest',
    'data': <String, dynamic>{
      'tab_key': tabKey,
      'store_key': storeKey,
      'sections': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'sec-$tabKey',
          'type': 'product_carousel',
          'order': 0,
          'visible': true,
          'config': <String, dynamic>{'title': title},
          'products': products,
        },
      ],
    },
  };
}

// ─── Environment ─────────────────────────────────────────────────────────────

/// Persistence without file I/O (which cannot complete under fake async).
class MemoryLayoutDiskStore extends LayoutDiskStore {
  MemoryLayoutDiskStore();

  final Map<String, StoredLayout> _themes = <String, StoredLayout>{};
  final Map<String, StoredLayout> _sections = <String, StoredLayout>{};

  @override
  StoredLayout? readTheme(ThemeKey key) => _themes[key.id];

  @override
  StoredLayout? readSections(SectionKey key) => _sections[key.id];

  @override
  Future<void> writeTheme(ThemeKey key, StoredLayout value) async =>
      _themes[key.id] = value;

  @override
  Future<void> writeSections(SectionKey key, StoredLayout value) async =>
      _sections[key.id] = value;
}

/// Real Hive on a temp dir + the app's static storage handles, so the tests
/// exercise the real persistence and scope code.
class StorefrontTestEnv {
  StorefrontTestEnv._(this.dir);

  final Directory dir;
  final FakeStorefrontAdapter adapter = FakeStorefrontAdapter();
  final List<StreamController<Map<String, dynamic>>> _sockets =
      <StreamController<Map<String, dynamic>>>[];
  final StreamController<Map<String, dynamic>> themeEvents =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> sectionEvents =
      StreamController<Map<String, dynamic>>.broadcast();
  int healthyReports = 0;
  int unavailableReports = 0;

  static Future<StorefrontTestEnv> create() async {
    final Directory dir =
        await Directory.systemTemp.createTemp('storefront_test_');
    final StorefrontTestEnv env = StorefrontTestEnv._(dir);
    Hive.init(dir.path);
    await env.openBoxes();
    return env;
  }

  Future<void> openBoxes() async {
    HiveService.settingsBox = await Hive.openBox<dynamic>('settings');
    HiveService.remoteThemeBox = await Hive.openBox<dynamic>('remote_theme');
    HiveService.sectionManifestBox =
        await Hive.openBox<dynamic>('section_manifests');
    HiveService.productsBox = await Hive.openBox<dynamic>('products');
    HiveService.categoriesBox = await Hive.openBox<dynamic>('categories');
    HiveService.bannersBox = await Hive.openBox<dynamic>('banners');
    HiveService.userBox = await Hive.openBox<dynamic>('user');
    HiveService.cacheMetaBox = await Hive.openBox<dynamic>('cache_meta');
    AppCacheManager.debugResetScopeMirror();
  }

  /// Simulates killing the app: flush + close every box, drop in-memory state.
  Future<void> killApp() async {
    await Hive.close();
    AppCacheManager.debugResetScopeMirror();
  }

  /// "Reopen": boxes come back from disk, statics re-seeded from Hive.
  Future<void> reopenApp() => openBoxes();

  ProviderContainer container({bool memoryDisk = false}) {
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'))
      ..httpClientAdapter = adapter;
    final ProviderContainer c = ProviderContainer(
      overrides: [
        storefrontDioProvider.overrideWithValue(dio),
        if (memoryDisk)
          layoutDiskStoreProvider.overrideWithValue(MemoryLayoutDiskStore()),
        layoutHealthSinkProvider.overrideWithValue(
          LayoutHealthSink(
            onHealthy: () => healthyReports++,
            onUnavailable: () => unavailableReports++,
          ),
        ),
        socketThemeUpdateStreamProvider.overrideWith(
          (Ref ref) => themeEvents.stream,
        ),
        socketSectionUpdateStreamProvider.overrideWith(
          (Ref ref) => sectionEvents.stream,
        ),
      ],
    );
    return c;
  }

  Future<void> setPriceModeSetting(String mode) =>
      HiveService.settingsBox.put(StorageKeys.priceMode, mode);

  Future<void> dispose() async {
    await themeEvents.close();
    await sectionEvents.close();
    for (final StreamController<Map<String, dynamic>> s in _sockets) {
      await s.close();
    }
    await Hive.close();
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  }
}

/// Lets queued microtasks/timers of zero duration run.
Future<void> settle([int rounds = 6]) async {
  for (int i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

@visibleForTesting
String hexColor(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Polls (real time) until [condition] holds — for fire-and-forget disk writes.
Future<void> waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final Stopwatch watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > timeout) {
      throw TimeoutException('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
