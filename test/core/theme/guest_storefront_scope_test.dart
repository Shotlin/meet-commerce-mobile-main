import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';
import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/network/api_interceptor.dart';
import 'package:bakaloo_flutter_app/core/providers/storefront_scope_provider.dart';
import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/core/storage/secure_storage_service.dart';
import 'package:bakaloo_flutter_app/core/theme/layout_flight.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_provider.dart';
import 'package:bakaloo_flutter_app/features/location/presentation/providers/guest_storefront_provider.dart';

import 'theme_test_harness.dart';

/// Guest vs signed-in storefront consistency.
///
/// The fake backend answers the way production does: WHICH storefront a
/// request gets depends on the credentials it carries (a guest's signed
/// storefront token, an account's bearer token, or nothing), and an
/// anonymous request gets the platform-default (blue) theme, no shop and no
/// products. The credentials are attached by the app's REAL `ApiInterceptor`.

const String kRed = '#D32F2F'; // FreshCuts (shop A)
const String kGreen = '#1B5E20'; // shop B
const String kBlue = '#88D4FE'; // platform default / anonymous
const int kBlueArgb = 0xFF88D4FE;
const List<String> kTabs = <String>['all', 'chicken', 'fish'];

int argb(String hex) => int.parse('FF${hex.substring(1)}', radix: 16);

String colorOf(String? shop) => switch (shop) {
      'shopA' => kRed,
      'shopB' => kGreen,
      _ => kBlue,
    };

class _FakeSecure extends SecureStorageService {
  String? token; // the account's access token; null = signed out

  @override
  Future<String?> getAccessToken() async => token;
}

/// A backend that resolves the shop from the credentials, like production.
class _ProdLikeBackend {
  final Map<String, String> guestTokens = <String, String>{
    'tok-shopA': 'shopA',
    'tok-shopB': 'shopB',
  };

  /// bearer token → the account's PRIMARY allocated shop (absent = the
  /// account has no allocation yet).
  final Map<String, String> accounts = <String, String>{
    'acct-a': 'shopA',
  };

  String? shopFor(FakeRequest r) {
    final Object? auth = r.options.headers['Authorization'];
    if (auth is String && auth.startsWith('Bearer ')) {
      return accounts[auth.substring(7)];
    }
    final Object? guest = r.options.headers['X-Storefront-Token'];
    return guest is String ? guestTokens[guest] : null;
  }

  void respond(FakeRequest r) {
    final String? shop = shopFor(r);
    final String variant = shop ?? 'default';
    if (r.isTheme) {
      final Map<String, dynamic> body = themePayload(
        storeKey: 'zepto',
        tabKeys: kTabs,
        topBarColor: colorOf(shop),
      );
      // The real backend always sends the field; null when it resolved no shop.
      (body['data'] as Map<String, dynamic>)['shop_id'] = shop;
      r.respondJson(body, headers: <String, List<String>>{
        'etag': <String>['"theme-$variant"'],
      });
      return;
    }
    if (r.homeTabKey != null) {
      final Map<String, dynamic> body =
          tabHomePayload(storeKey: 'zepto', tabKey: r.homeTabKey!);
      (body['data'] as Map<String, dynamic>)['shop_id'] = shop;
      r.respondJson(body);
      return;
    }
    final String tab = r.tabKey!;
    final Map<String, dynamic> body = sectionsPayload(
      storeKey: 'zepto',
      tabKey: tab,
      title: '$variant:$tab',
    );
    (body['data'] as Map<String, dynamic>)['shop_id'] = shop;
    r.respondJson(body, headers: <String, List<String>>{
      'etag': <String>['"sec-$variant-$tab"'],
    });
  }
}

Map<String, dynamic> _guestRecord(String shop, {DateTime? expires}) =>
    <String, dynamic>{
      'token': 'tok-$shop',
      'shopId': shop,
      'shopName': shop,
      'pincode': '201301',
      'lat': 28.5,
      'lng': 77.4,
      'expiresAt': (expires ?? DateTime.now().add(const Duration(days: 7)))
          .toIso8601String(),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ThemeTestEnv env;
  late _ProdLikeBackend backend;
  late _FakeSecure secure;
  late ProviderContainer container;
  final List<ProviderSubscription<Object?>> keepAlive =
      <ProviderSubscription<Object?>>[];
  final int neutralArgb =
      RemoteTheme.neutral().sections.topBar.backgroundColor.toARGB32();

  void wireDio() {
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'))
      ..httpClientAdapter = env.adapter
      ..interceptors.add(ApiInterceptor(secure));
    layoutDioFactory = () => dio;
  }

  /// Every top-bar colour the screen ever showed, in order.
  List<int> watchColors(ProviderContainer c) {
    final List<int> seen = <int>[];
    keepAlive
      ..add(c.listen<RemoteTheme>(
        activeTabThemeProvider,
        (_, RemoteTheme t) =>
            seen.add(t.sections.topBar.backgroundColor.toARGB32()),
        fireImmediately: true,
      ))
      ..add(c.listen(activeSectionManifestProvider, (_, __) {}))
      ..add(c.listen(activeSectionsStatusProvider, (_, __) {}))
      ..add(c.listen(tabThemesProvider, (_, __) {}));
    return seen;
  }

  int topBar(ProviderContainer c) =>
      c.read(activeTabThemeProvider).sections.topBar.backgroundColor.toARGB32();

  String? titleOf(ProviderContainer c) {
    final sections = c.read(activeSectionManifestProvider).sections;
    return sections.isEmpty ? null : sections.first.config['title'] as String?;
  }

  Future<void> saveGuest(String shop, {DateTime? expires}) =>
      HiveService.settingsBox.put(
        StorageKeys.guestStorefrontLocation,
        _guestRecord(shop, expires: expires),
      );

  bool sentCredentials(FakeRequest r) =>
      r.options.headers.containsKey('X-Storefront-Token') ||
      r.options.headers.containsKey('Authorization');

  setUp(() async {
    env = await ThemeTestEnv.create();
    backend = _ProdLikeBackend();
    secure = _FakeSecure();
    wireDio();
    env.adapter.autoRespond = backend.respond;
    container = env.container();
  });

  tearDown(() async {
    for (final ProviderSubscription<Object?> s in keepAlive) {
      s.close();
    }
    keepAlive.clear();
    container.dispose();
    await env.dispose();
  });

  group('guest cold launch', () {
    test('sends the guest token, shows the FreshCuts theme + shop sections, '
        'never the blue default', () async {
      await saveGuest('shopA');
      await AppCacheManager.setShopScope(<String>['shopA']);
      final List<int> colors = watchColors(container);

      await waitUntil(() => container.read(themeResolvedProvider));
      await waitUntil(() => titleOf(container) != null);

      final FakeRequest theme =
          env.adapter.requests.firstWhere((r) => r.isTheme);
      expect(theme.options.headers['X-Storefront-Token'], 'tok-shopA');
      expect(topBar(container), argb(kRed));
      expect(titleOf(container), 'shopA:all');
      expect(colors.toSet().difference(<int>{neutralArgb, argb(kRed)}), isEmpty,
          reason: 'only the neutral placeholder, then the real theme');
      expect(colors, isNot(contains(kBlueArgb)));
    });

    test('app restart as a guest renders the shop theme on the FIRST frame',
        () async {
      await saveGuest('shopA');
      await AppCacheManager.setShopScope(<String>['shopA']);
      watchColors(container);
      await waitUntil(() => container.read(themeResolvedProvider));
      await waitUntil(() => titleOf(container) != null);

      for (final ProviderSubscription<Object?> s in keepAlive) {
        s.close();
      }
      keepAlive.clear();
      container.dispose();
      await env.killAndReopenApp();
      wireDio();
      env.adapter.requests.clear();

      container = env.container();
      final List<int> colors = watchColors(container);
      // No await: the very first read after "launch".
      expect(container.read(themeResolvedProvider), isTrue);
      expect(topBar(container), argb(kRed));
      expect(colors.first, argb(kRed));
      expect(colors, isNot(contains(kBlueArgb)));
      expect(colors, isNot(contains(neutralArgb)));

      await settle();
      expect(
        env.adapter.requests.where((r) => !sentCredentials(r)),
        isEmpty,
        reason: 'revalidation still carries the guest token',
      );
    });
  });

  group('the request identity always matches the cache identity', () {
    test('ROOT CAUSE: a request sent without the guest token (record missing) '
        'is answered with the blue default — it is refused, never stored or '
        'shown', () async {
      // Scope says shop A, but the token is not in Hive (e.g. restored from
      // the encrypted backup / iOS keychain after a reinstall).
      await AppCacheManager.setShopScope(<String>['shopA']);
      final List<int> colors = watchColors(container);

      await waitUntil(
        () => env.adapter.requests.any((r) => r.isTheme),
      );
      await settle();

      expect(env.adapter.requests.firstWhere((r) => r.isTheme).options.headers,
          isNot(contains('X-Storefront-Token')));
      expect(container.read(themeResolvedProvider), isFalse);
      expect(colors, isNot(contains(kBlueArgb)));
      expect(topBar(container), neutralArgb);
      expect(HiveService.remoteThemeBox.keys, isEmpty,
          reason: 'the anonymous payload is not persisted under the shop key');
      expect(HiveService.sectionManifestBox.keys, isEmpty);
      expect(env.unavailableReports, 0,
          reason: 'not an outage: no "service unavailable" screen');

      // The token becomes available: the next revalidation shows the real one.
      await saveGuest('shopA');
      await container.read(storefrontSyncProvider).revalidateActive(force: true);
      await settle();
      expect(topBar(container), argb(kRed));
      expect(colors, isNot(contains(kBlueArgb)));
    });

    test('token of shop B while the scope still says shop A (location change '
        'window): shop B\'s answer is not stored under shop A', () async {
      await saveGuest('shopA');
      await AppCacheManager.setShopScope(<String>['shopA']);
      watchColors(container);
      await waitUntil(() => titleOf(container) == 'shopA:all');

      // The guest re-locates: Hive gets shop B's token first, the scope a
      // moment later.
      await saveGuest('shopB');
      await container.read(storefrontSyncProvider).revalidateActive(force: true);
      await settle();

      expect(topBar(container), argb(kRed), reason: 'A is still A');
      expect(titleOf(container), 'shopA:all');

      await AppCacheManager.setShopScope(<String>['shopB']);
      await waitUntil(() => titleOf(container) == 'shopB:all');
      expect(topBar(container), argb(kGreen));
    });

    test('no shop resolved: nothing is requested, only placeholders', () async {
      final List<int> colors = watchColors(container);
      await settle();

      expect(env.adapter.requests, isEmpty);
      expect(container.read(themeResolvedProvider), isFalse);
      expect(container.read(activeSectionsStatusProvider),
          SectionsStatus.loading);
      expect(colors, <int>[neutralArgb]);
    });

    test('an anonymous entry left on disk by an older build is never read',
        () async {
      await HiveService.remoteThemeBox.put(
        AppCacheManager.scopedKey('layout_theme_v3',
            shopScope: 'anon', extra: 'zepto'),
        encodeLayoutEnvelope(
          raw: jsonEncode(themePayload(
            storeKey: 'zepto',
            tabKeys: kTabs,
            topBarColor: kBlue,
          )['data']),
          savedAt: DateTime.now(),
        ),
      );
      watchColors(container);
      await settle();
      expect(container.read(themeResolvedProvider), isFalse);
      expect(topBar(container), neutralArgb);
    });
  });

  group('guest → login (same location)', () {
    test('the storefront does not change: same key, same theme, no new '
        'request, no flash', () async {
      await saveGuest('shopA');
      await AppCacheManager.setShopScope(<String>['shopA']);
      final List<int> colors = watchColors(container);
      await waitUntil(() => titleOf(container) == 'shopA:all');
      final int before = env.adapter.requests.length;
      final int emissions = colors.length;

      // Sign in: a bearer replaces the guest token, and the allocation call
      // returns EVERY shop that serves the address, primary flagged.
      secure.token = 'acct-a';
      await AppCacheManager.applyAllocationResponse(<String, dynamic>{
        'data': <String, dynamic>{
          'shops': <Map<String, dynamic>>[
            <String, dynamic>{'shop_id': 'shopB', 'is_primary': false},
            <String, dynamic>{'shop_id': 'shopA', 'is_primary': true},
          ],
        },
      });
      await settle();

      expect(AppCacheManager.currentShopScope, 'shopA',
          reason: 'the primary shop — not "shopA,shopB"');
      expect(container.read(storefrontScopeProvider).shopId, 'shopA');
      expect(env.adapter.requests.length, before,
          reason: 'identical scope ⇒ the guest\'s public storefront is reused');
      expect(colors.length, emissions, reason: 'no rebuild, no flash');
      expect(topBar(container), argb(kRed));
    });

    test('a signed-in revalidation reaches the same shop and changes nothing',
        () async {
      await saveGuest('shopA');
      await AppCacheManager.setShopScope(<String>['shopA']);
      final List<int> colors = watchColors(container);
      await waitUntil(() => titleOf(container) == 'shopA:all');
      final int emissions = colors.length;

      secure.token = 'acct-a';
      await container.read(storefrontSyncProvider).revalidateActive(force: true);
      await settle();

      final Iterable<FakeRequest> signedIn = env.adapter.requests
          .where((r) => r.options.headers['Authorization'] == 'Bearer acct-a');
      expect(signedIn, isNotEmpty);
      expect(signedIn.every((r) => !r.options.headers
          .containsKey('X-Storefront-Token')), isTrue);
      expect(colors.length, emissions);
      expect(topBar(container), argb(kRed));
      expect(titleOf(container), 'shopA:all');
    });

    test('signed in but the account has no allocation YET: the anonymous '
        'answer is refused and the guest\'s storefront stays on screen',
        () async {
      await saveGuest('shopA');
      await AppCacheManager.setShopScope(<String>['shopA']);
      final List<int> colors = watchColors(container);
      await waitUntil(() => titleOf(container) == 'shopA:all');

      secure.token = 'acct-new'; // valid session, no allocation on the server
      await container.read(storefrontSyncProvider).revalidateActive(force: true);
      await settle();

      expect(topBar(container), argb(kRed));
      expect(titleOf(container), 'shopA:all');
      expect(colors, isNot(contains(kBlueArgb)));
      expect(env.unavailableReports, 0);
    });
  });

  group('login → logout', () {
    test('the scope returns to the guest\'s shop (not "anon"), so the guest '
        'storefront is the same one as before login', () async {
      await saveGuest('shopA');
      await AppCacheManager.setShopScope(<String>['shopA']);
      watchColors(container);
      await waitUntil(() => titleOf(container) == 'shopA:all');

      // Sign in as a customer whose primary shop is B (a different address).
      backend.accounts['acct-b'] = 'shopB';
      secure.token = 'acct-b';
      await AppCacheManager.setShopScope(<String>['shopB']);
      await waitUntil(() => titleOf(container) == 'shopB:all');
      expect(topBar(container), argb(kGreen));

      // Log out: what AuthNotifier.logout() does.
      secure.token = null;
      await AppCacheManager.resetShopScope();
      final int afterLogout = env.adapter.requests.length;

      expect(AppCacheManager.currentShopScope, 'shopA');
      expect(container.read(shopScopeProvider), 'shopA');
      // The guest's storefront is on screen at once, from its own cache.
      expect(topBar(container), argb(kRed));
      await settle();
      expect(titleOf(container), 'shopA:all');
      // Whatever went out after logout carried the guest token, never nothing.
      expect(
        env.adapter.requests.skip(afterLogout).every(sentCredentials),
        isTrue,
      );
    });

    test('with no saved guest storefront the scope is unresolved', () async {
      await AppCacheManager.setShopScope(<String>['shopB']);
      await AppCacheManager.resetShopScope();
      expect(AppCacheManager.currentShopScope, AppCacheManager.anonShopScope);
    });

    test('an expired guest storefront does not restore a scope', () async {
      await saveGuest('shopA',
          expires: DateTime.now().subtract(const Duration(days: 1)));
      await AppCacheManager.setShopScope(<String>['shopB']);
      await AppCacheManager.resetShopScope();
      expect(AppCacheManager.currentShopScope, AppCacheManager.anonShopScope);
    });
  });

  group('store A → store B', () {
    test('a shop switch shows only B, and A returns instantly', () async {
      await saveGuest('shopA');
      await AppCacheManager.setShopScope(<String>['shopA']);
      final List<int> colors = watchColors(container);
      await waitUntil(() => titleOf(container) == 'shopA:all');

      await saveGuest('shopB');
      await AppCacheManager.setShopScope(<String>['shopB']);
      await waitUntil(() => titleOf(container) == 'shopB:all');
      expect(topBar(container), argb(kGreen));

      // Back to A: served from A's own cache on the first frame.
      await saveGuest('shopA');
      await AppCacheManager.setShopScope(<String>['shopA']);
      expect(container.read(themeResolvedProvider), isTrue);
      expect(topBar(container), argb(kRed));
      expect(colors, isNot(contains(kBlueArgb)));
    });

    test('slow network: shop B\'s request is held while A\'s late answer '
        'arrives — B ends up showing B only', () async {
      env.adapter.autoRespond = null; // hold every request
      await saveGuest('shopA');
      await AppCacheManager.setShopScope(<String>['shopA']);
      final List<int> colors = watchColors(container);
      await settle();
      final List<FakeRequest> aRequests = env.adapter.pending.toList();

      await saveGuest('shopB');
      await AppCacheManager.setShopScope(<String>['shopB']);
      await settle();
      final List<FakeRequest> bRequests = env.adapter.pending
          .where((r) => !aRequests.contains(r))
          .toList();
      expect(bRequests, isNotEmpty);

      // A's late answers (if they were not aborted) and then B's.
      for (final FakeRequest r in aRequests) {
        backend.respond(r);
      }
      for (final FakeRequest r in bRequests) {
        backend.respond(r);
      }
      await waitUntil(() => titleOf(container) == 'shopB:all');
      expect(topBar(container), argb(kGreen));
      expect(colors, isNot(contains(kBlueArgb)));
    });
  });

  group('one identity for guest and account', () {
    test('login state is not part of the storefront scope', () {
      const StorefrontScope a = StorefrontScope(
          storeKey: 'zepto', shopScope: 'shopA', priceMode: 'retail');
      const StorefrontScope b = StorefrontScope(
          storeKey: 'zepto', shopScope: 'shopA', priceMode: 'retail');
      expect(a, b);
      expect(a.shopId, 'shopA');
      expect(a.themeKey, b.themeKey);
      expect(a.sectionKey('all'), b.sectionKey('all'));
      const StorefrontScope none = StorefrontScope(
          storeKey: 'zepto', shopScope: 'anon', priceMode: 'retail');
      expect(none.isResolved, isFalse);
      expect(none.shopId, isNull);
    });

    test('applyAllocationResponse keys by the PRIMARY shop only', () async {
      Future<String> scopeAfter(List<Map<String, dynamic>> shops) async {
        await AppCacheManager.resetShopScope();
        await AppCacheManager.applyAllocationResponse(<String, dynamic>{
          'data': <String, dynamic>{'shops': shops},
        });
        return AppCacheManager.currentShopScope;
      }

      expect(
        await scopeAfter(<Map<String, dynamic>>[
          <String, dynamic>{'shop_id': 'shopB', 'is_primary': false},
          <String, dynamic>{'shop_id': 'shopA', 'is_primary': true},
        ]),
        'shopA',
      );
      expect(
        await scopeAfter(<Map<String, dynamic>>[
          <String, dynamic>{'shop_id': 'shopB'},
          <String, dynamic>{'shop_id': 'shopA'},
        ]),
        'shopB',
        reason: 'none flagged ⇒ the first, like the backend',
      );
      expect(await scopeAfter(<Map<String, dynamic>>[]), 'anon');
    });

    test('a multi-shop scope stored by an earlier build is normalised',
        () async {
      await HiveService.settingsBox
          .put('bakaloo_app_cache_shop_scope', 'shopA,shopB');
      AppCacheManager.debugResetScopeMirror();
      expect(AppCacheManager.currentShopScope, 'anon');
      expect(AppCacheManager.shopScopeListenable.value, 'anon');

      await saveGuest('shopB');
      AppCacheManager.debugResetScopeMirror();
      expect(AppCacheManager.currentShopScope, 'shopB');
      expect(AppCacheManager.shopScopeListenable.value, 'shopB');
    });

    test('payloadMatchesShopScope', () {
      expect(payloadMatchesShopScope(<String, dynamic>{'shop_id': 'a'}, 'a'),
          isTrue);
      expect(payloadMatchesShopScope(<String, dynamic>{'shop_id': 'b'}, 'a'),
          isFalse);
      expect(payloadMatchesShopScope(<String, dynamic>{'shop_id': null}, 'a'),
          isFalse);
      expect(payloadMatchesShopScope(<String, dynamic>{'x': 1}, 'a'), isTrue,
          reason: 'older backend without the echo');
    });
  });

  group('guest storefront restore', () {
    const MethodChannel secureChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureChannel, null);
    });

    void mockSecureBackup(Map<String, dynamic> record) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureChannel, (MethodCall call) async {
        if (call.method == 'read') {
          return jsonEncode(record);
        }
        return null;
      });
    }

    ProviderContainer guestContainer() => ProviderContainer(
          overrides: [secureStorageProvider.overrideWithValue(secure)],
        );

    test('a record restored from the encrypted backup is put back where the '
        'request interceptor reads it', () async {
      mockSecureBackup(_guestRecord('shopA'));
      expect(HiveService.settingsBox.get(StorageKeys.guestStorefrontLocation),
          isNull);

      final ProviderContainer c = guestContainer();
      addTearDown(c.dispose);
      c.read(guestStorefrontProvider);
      await waitUntil(() => c.read(guestStorefrontProvider).isReady);

      final dynamic inHive =
          HiveService.settingsBox.get(StorageKeys.guestStorefrontLocation);
      expect(inHive, isA<Map>());
      expect((inHive as Map)['token'], 'tok-shopA');
      expect(AppCacheManager.currentShopScope, 'shopA');

      // ...so the next storefront request carries the token.
      final ProviderContainer view = env.container();
      addTearDown(view.dispose);
      watchColors(view);
      await waitUntil(() => view.read(themeResolvedProvider));
      expect(env.adapter.requests.firstWhere((r) => r.isTheme).options.headers,
          containsPair('X-Storefront-Token', 'tok-shopA'));
    });

    test('a device with a saved account session is not a guest: the saved '
        'guest shop does not claim the scope', () async {
      await saveGuest('shopA');
      await AppCacheManager.setShopScope(<String>['shopB']); // account's shop
      secure.token = 'acct-b';

      final ProviderContainer c = guestContainer();
      addTearDown(c.dispose);
      c.read(guestStorefrontProvider);
      await waitUntil(() => c.read(guestStorefrontProvider).isReady);

      expect(AppCacheManager.currentShopScope, 'shopB');
    });

    test('a fresh guest restore claims its shop', () async {
      await saveGuest('shopA');
      final ProviderContainer c = guestContainer();
      addTearDown(c.dispose);
      c.read(guestStorefrontProvider);
      await waitUntil(() => c.read(guestStorefrontProvider).isReady);
      expect(AppCacheManager.currentShopScope, 'shopA');
    });
  });
}
