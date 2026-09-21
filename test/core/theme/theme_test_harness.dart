import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';
import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/core/theme/layout_flight.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart';

/// One request the fake backend was asked to serve.
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
  String? get tabKey =>
      RegExp(r'^/theme/tabs/([^/]+)/sections$').firstMatch(path)?.group(1);
  String? get homeTabKey =>
      RegExp(r'^/theme/tabs/([^/]+)/home$').firstMatch(path)?.group(1);

  void respondJson(
    Object body, {
    int status = 200,
    Map<String, List<String>>? headers,
  }) {
    if (_completer.isCompleted) return;
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
    if (_completer.isCompleted) return;
    _completer.complete(ResponseBody.fromString('', 304));
  }

  void fail() {
    if (_completer.isCompleted) return;
    _completer.completeError(
      DioException.connectionError(
        requestOptions: options,
        reason: 'test network failure',
      ),
    );
  }
}

/// Every request is recorded and held until the test answers it, which is what
/// lets a test deliver responses out of order.
class FakeBackendAdapter implements HttpClientAdapter {
  final List<FakeRequest> requests = <FakeRequest>[];
  void Function(FakeRequest request)? autoRespond;

  Iterable<FakeRequest> get pending =>
      requests.where((FakeRequest r) => !r.done && !r.cancelled);
  int count(bool Function(FakeRequest r) test) => requests.where(test).length;

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
        },
      ],
    },
  };
}

Map<String, dynamic> tabHomePayload({
  required String storeKey,
  required String tabKey,
}) {
  return <String, dynamic>{
    'success': true,
    'message': 'Tab home content',
    'data': <String, dynamic>{
      'store_key': storeKey,
      'tab_key': tabKey,
      'seasonal_products': <dynamic>[],
      'featured_products': <dynamic>[],
      'deal_products': <dynamic>[],
      'trending_products': <dynamic>[],
      'category_sections': <dynamic>[],
    },
  };
}

/// Persistence without file I/O (which cannot complete under fake async).
class MemoryLayoutPersistence implements LayoutPersistence {
  final Map<String, String> _data = <String, String>{};

  @override
  String? read(LayoutBox box, String key) => _data['${box.name}/$key'];

  @override
  Future<void> write(LayoutBox box, String key, String value) async =>
      _data['${box.name}/$key'] = value;
}

/// Real Hive on a temp dir + the app's static handles (real persistence and
/// scope code), a fake backend, and the test seams wired up.
class ThemeTestEnv {
  ThemeTestEnv._(this.dir);

  final Directory dir;
  final FakeBackendAdapter adapter = FakeBackendAdapter();
  int healthyReports = 0;
  int unavailableReports = 0;

  static Future<ThemeTestEnv> create({bool memoryPersistence = false}) async {
    final Directory dir =
        await Directory.systemTemp.createTemp('theme_test_');
    final ThemeTestEnv env = ThemeTestEnv._(dir);
    Hive.init(dir.path);
    await env.openBoxes();
    env._wire(memoryPersistence: memoryPersistence);
    return env;
  }

  void _wire({bool memoryPersistence = false}) {
    resetLayoutMemoryForTests();
    layoutPersistence = memoryPersistence
        ? MemoryLayoutPersistence()
        : const HiveLayoutPersistence();
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'))
      ..httpClientAdapter = adapter;
    layoutDioFactory = () => dio;
    layoutHealthHook = ({required bool healthy}) {
      healthy ? healthyReports++ : unavailableReports++;
    };
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

  /// Simulates killing the app, then reopening it from disk.
  Future<void> killAndReopenApp() async {
    await Hive.close();
    AppCacheManager.debugResetScopeMirror();
    await openBoxes();
    // A fresh process has empty in-memory caches.
    resetLayoutMemoryForTests();
    layoutPersistence = const HiveLayoutPersistence();
    _rewire();
  }

  void _rewire() {
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'))
      ..httpClientAdapter = adapter;
    layoutDioFactory = () => dio;
  }

  ProviderContainer container() => ProviderContainer();

  Future<void> setPriceModeSetting(String mode) =>
      HiveService.settingsBox.put(StorageKeys.priceMode, mode);

  Future<void> dispose() async {
    layoutDioFactory = null;
    layoutHealthHook = null;
    layoutPersistence = const HiveLayoutPersistence();
    resetLayoutMemoryForTests();
    await Hive.close();
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  }
}

Future<void> settle([int rounds = 6]) async {
  for (int i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

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
