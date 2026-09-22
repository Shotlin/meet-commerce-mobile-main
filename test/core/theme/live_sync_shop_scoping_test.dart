// Requirement 8 ("make dashboard → mobile propagation fast … do not globally
// invalidate every shop/tab if only one configuration changed"): a socket
// event that names ONE shop must not cause a DIFFERENT shop's already-open
// app to re-fetch — while a shop-less (global-theme) event, or an event for
// the shop actually on screen, still must.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_provider.dart';

import 'theme_test_harness.dart';

const List<String> kTabs = <String>['all', 'chicken', 'fish'];

void serve(FakeRequest r, String shop, {String color = '#D32F2F'}) {
  if (r.isTheme) {
    r.respondJson(
      themePayload(
          storeKey: 'zepto', shopId: shop, tabKeys: kTabs, topBarColor: color),
      headers: <String, List<String>>{
        'etag': <String>['"theme-$shop-$color"']
      },
    );
    return;
  }
  if (r.homeTabKey != null) {
    r.respondJson(
        tabHomePayload(storeKey: 'zepto', tabKey: r.homeTabKey!, shopId: shop));
    return;
  }
  final String tab = r.tabKey!;
  r.respondJson(
    sectionsPayload(
        storeKey: 'zepto', tabKey: tab, title: '$shop:$tab', shopId: shop),
    headers: <String, List<String>>{
      'etag': <String>['"sec-$shop-$tab"']
    },
  );
}

void main() {
  late ThemeTestEnv env;
  late ProviderContainer container;
  final List<ProviderSubscription<Object?>> keepAlive =
      <ProviderSubscription<Object?>>[];

  void watchVisible(ProviderContainer c) {
    keepAlive
      ..add(c.listen(activeSectionManifestProvider, (_, __) {}))
      ..add(c.listen(activeSectionsStatusProvider, (_, __) {}))
      ..add(c.listen(activeTabThemeProvider, (_, __) {}))
      ..add(c.listen(tabThemesProvider, (_, __) {}));
  }

  setUp(() async {
    env = await ThemeTestEnv.create();
    await AppCacheManager.setShopScope(<String>['shopA']);
    container = env.container();
    watchVisible(container);
  });

  tearDown(() async {
    for (final ProviderSubscription<Object?> s in keepAlive) {
      s.close();
    }
    keepAlive.clear();
    container.dispose();
    await env.dispose();
  });

  Future<void> loadShopA() async {
    await settle();
    for (final FakeRequest r in env.adapter.pending.toList()) {
      serve(r, 'shopA');
    }
    await settle();
  }

  /// Fires the event and lets the debounced revalidation (or lack of it) run.
  Future<void> fireThemeEvent(Map<String, dynamic> data) async {
    container.read(storefrontSyncProvider).onThemeEvent(data);
    await Future<void>.delayed(
        kStorefrontSyncDebounce + const Duration(milliseconds: 50));
  }

  Future<void> fireSectionEvent(Map<String, dynamic> data) async {
    container.read(storefrontSyncProvider).onSectionEvent(data);
    await Future<void>.delayed(
        kStorefrontSyncDebounce + const Duration(milliseconds: 50));
  }

  group('theme:update — shop-scoped', () {
    test("an event for a DIFFERENT shop issues no request at all", () async {
      await loadShopA();
      final int before = env.adapter.requests.length;

      await fireThemeEvent(<String, dynamic>{
        'tabKey': 'all',
        'storeKey': 'zepto',
        'shopId': 'shopB',
      });

      expect(env.adapter.requests.length, before,
          reason: "Kolkata's (shopB's) edit must not touch a shopA session");
    });

    test('an event for THIS shop revalidates (theme request re-issued)',
        () async {
      await loadShopA();
      final int before = env.adapter.requests.length;

      await fireThemeEvent(<String, dynamic>{
        'tabKey': 'all',
        'storeKey': 'zepto',
        'shopId': 'shopA',
      });

      expect(env.adapter.requests.length, greaterThan(before));
      expect(env.adapter.requests.skip(before).any((r) => r.isTheme), isTrue);
    });

    test(
        'a shop-less (global theme) event revalidates regardless of which '
        'shop is on screen — it can affect any shop without its own override',
        () async {
      await loadShopA();
      final int before = env.adapter.requests.length;

      await fireThemeEvent(
          <String, dynamic>{'tabKey': 'all', 'storeKey': 'zepto'});

      expect(env.adapter.requests.length, greaterThan(before));
    });

    test('snake_case shop_id is read the same as camelCase shopId', () async {
      await loadShopA();
      final int before = env.adapter.requests.length;

      await fireThemeEvent(<String, dynamic>{
        'tab_key': 'all',
        'store_key': 'zepto',
        'shop_id': 'shopB',
      });

      expect(env.adapter.requests.length, before);
    });

    test(
        'a different STORE is skipped even with a matching shopId '
        '(cross-store coincidence must not revalidate)', () async {
      await loadShopA();
      final int before = env.adapter.requests.length;

      await fireThemeEvent(<String, dynamic>{
        'tabKey': 'all',
        'storeKey': 'off_zone',
        'shopId': 'shopA',
      });

      expect(env.adapter.requests.length, before);
    });
  });

  group('section:update — shop-scoped', () {
    test('a different shop\'s section edit issues no request', () async {
      await loadShopA();
      final int before = env.adapter.requests.length;

      await fireSectionEvent(<String, dynamic>{
        'tab_key': 'all',
        'store_key': 'zepto',
        'shop_id': 'shopB',
      });

      expect(env.adapter.requests.length, before);
    });

    test("this shop's section edit on the ACTIVE tab revalidates", () async {
      await loadShopA();
      final int before = env.adapter.requests.length;

      await fireSectionEvent(<String, dynamic>{
        'tab_key': 'all',
        'store_key': 'zepto',
        'shop_id': 'shopA',
      });

      expect(env.adapter.requests.length, greaterThan(before));
    });

    test(
        "this shop's edit on a tab that ISN'T active still issues no "
        'request (existing tabKey filter is preserved)', () async {
      await loadShopA();
      final int before = env.adapter.requests.length;

      await fireSectionEvent(<String, dynamic>{
        'tab_key': 'fish', // active tab is 'all'
        'store_key': 'zepto',
        'shop_id': 'shopA',
      });

      expect(env.adapter.requests.length, before);
    });
  });

  group("a shop-scoped event never affects a DIFFERENT shop's held cache", () {
    test(
        'marking shopB stale leaves shopA\'s already-fresh theme fresh — '
        'switching back to shopA (a re-resolve) shows it instantly, no request',
        () async {
      await loadShopA();
      container.read(storefrontSyncProvider).onThemeEvent(<String, dynamic>{
        'tabKey': 'all',
        'storeKey': 'zepto',
        'shopId': 'shopB',
      });
      await settle();

      final int before = env.adapter.requests.length;
      await container.read(storefrontSyncProvider).revalidateActive();
      await settle();

      expect(env.adapter.requests.length, before,
          reason:
              'shopA content was never marked stale, so nothing re-fetches');
    });
  });
}
