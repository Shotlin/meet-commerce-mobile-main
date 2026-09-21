import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';
import 'package:bakaloo_flutter_app/core/providers/price_mode_provider.dart';
import 'package:bakaloo_flutter_app/core/providers/store_provider.dart';
import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/core/storefront/layout_disk_store.dart';
import 'package:bakaloo_flutter_app/core/storefront/layout_keys.dart';
import 'package:bakaloo_flutter_app/core/storefront/storefront_scope.dart';
import 'package:bakaloo_flutter_app/core/storefront/storefront_sync.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_provider.dart';

import 'storefront_harness.dart';

const String kRed = '#D32F2F'; // shop A — the FreshCuts theme
const String kGreen = '#1B5E20'; // shop B
const int kLegacyZeptoBlue = 0xFF88D4FE;

const List<String> kTabs = <String>['all', 'chicken', 'fish', 'mutton', 'eggs'];

String colorFor(String shop) => shop == 'shopB' ? kGreen : kRed;

/// Answers a request the way the real backend would for [shop].
void serve(FakeRequest r, String shop, {String? mode}) {
  if (r.isTheme) {
    r.respondJson(
      themePayload(
        storeKey: 'zepto',
        shopId: shop,
        tabKeys: kTabs,
        topBarColor: colorFor(shop),
      ),
      headers: <String, List<String>>{
        'etag': <String>['"theme-$shop"'],
      },
    );
    return;
  }
  final String tab = r.tabKey!;
  final String priceMode = r.query['priceMode'] as String;
  r.respondJson(
    sectionsPayload(
      storeKey: 'zepto',
      tabKey: tab,
      title: '$shop:$tab:$priceMode',
    ),
    headers: <String, List<String>>{
      'etag': <String>['"sec-$shop-$tab-$priceMode"'],
    },
  );
}

String? titleOf(ProviderContainer c) {
  final ActiveSections s = c.read(activeSectionsProvider);
  return s.sections.isEmpty ? null : s.sections.first.config['title'] as String?;
}

void main() {
  late StorefrontTestEnv env;
  late ProviderContainer container;
  final List<ProviderSubscription<Object?>> keepAlive =
      <ProviderSubscription<Object?>>[];

  /// Widgets keep the visible providers alive; the tests do the same.
  void watchVisible(ProviderContainer c) {
    keepAlive
      ..add(c.listen(activeSectionsProvider, (_, __) {}))
      ..add(c.listen(activeTabThemeProvider, (_, __) {}))
      ..add(c.listen(tabThemesProvider, (_, __) {}));
  }

  setUp(() async {
    env = await StorefrontTestEnv.create();
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

  group('fresh launch', () {
    test('shows a neutral placeholder — never the legacy Zepto theme — then '
        'the Theme Builder theme', () async {
      final List<int> topBarColors = <int>[];
      final List<bool> ready = <bool>[];
      container.listen<RemoteTheme>(
        activeTabThemeProvider,
        (_, RemoteTheme t) => topBarColors.add(t.sections.topBar.backgroundColor.toARGB32()),
        fireImmediately: true,
      );
      container.listen<bool>(
        themeReadyProvider,
        (_, bool v) => ready.add(v),
        fireImmediately: true,
      );

      await settle();
      // Nothing cached: the theme is unresolved and tabs are absent.
      expect(container.read(themeReadyProvider), isFalse);
      expect(container.read(themeTabsProvider), isNull);
      expect(container.read(activeSectionsProvider).status, SectionsStatus.loading);
      expect(topBarColors.single, isNot(kLegacyZeptoBlue));
      expect(topBarColors.single, 0xFFFFFFFF, reason: 'neutral, not a store theme');

      for (final FakeRequest r in env.adapter.pending.toList()) {
        serve(r, 'shopA');
      }
      await settle();

      expect(container.read(themeReadyProvider), isTrue);
      expect(topBarColors.last, 0xFFD32F2F);
      expect(topBarColors, isNot(contains(kLegacyZeptoBlue)));
      expect(container.read(activeSectionsProvider).status, SectionsStatus.ready);
      expect(titleOf(container), 'shopA:all:retail');
      expect(container.read(themeTabsProvider)!.map((t) => t.tabKey), kTabs);
    });

    test('a failed first load is an error state, never a bundled default theme',
        () async {
      await settle();
      for (final FakeRequest r in env.adapter.pending.toList()) {
        r.fail();
      }
      await settle();

      expect(container.read(themeReadyProvider), isFalse);
      expect(container.read(themeTabsProvider), isNull);
      expect(container.read(activeSectionsProvider).status, SectionsStatus.failed);
      expect(env.unavailableReports, greaterThan(0));
      expect(
        container.read(activeTabThemeProvider).sections.topBar.backgroundColor.toARGB32(),
        isNot(kLegacyZeptoBlue),
      );
    });
  });

  group('rapid tab switching', () {
    test('All → Chicken → Fish → Mutton → Eggs: Eggs wins, stale requests '
        'are aborted, no endless loader', () async {
      await loadShopA();
      final int requestsBefore = env.adapter.requests.length;

      final tab = container.read(selectedCategoryIdProvider.notifier);
      for (final String key in <String>['chicken', 'fish', 'mutton', 'eggs']) {
        tab.select(key);
        // No frame/await between taps — a genuinely rapid sequence.
        expect(container.read(activeTabKeyProvider), key);
        container.read(activeSectionsProvider);
      }
      await settle();

      final List<FakeRequest> issued =
          env.adapter.requests.skip(requestsBefore).toList();
      final Map<String?, FakeRequest> byTab = <String?, FakeRequest>{
        for (final FakeRequest r in issued.where((r) => r.tabKey != null))
          r.tabKey: r,
      };
      expect(byTab.keys.toSet(), containsAll(<String>['eggs']));
      // Everything superseded was aborted; only the latest is still alive.
      for (final String stale in <String>['chicken', 'fish', 'mutton']) {
        if (byTab.containsKey(stale)) {
          expect(byTab[stale]!.cancelled, isTrue, reason: '$stale is stale');
        }
      }
      expect(byTab['eggs']!.cancelled, isFalse);
      // Exactly one request is still alive on the wire: the latest tab's.
      expect(
        env.adapter.pending.where((r) => r.tabKey != null).map((r) => r.tabKey),
        <String?>['eggs'],
      );
      expect(container.read(activeSectionsProvider).status, SectionsStatus.loading);

      // The stale responses "arrive late" — they must change nothing.
      for (final String stale in <String>['chicken', 'fish', 'mutton']) {
        if (byTab.containsKey(stale)) {
          serve(byTab[stale]!, 'shopA');
        }
      }
      await settle();
      expect(container.read(activeSectionsProvider).status, SectionsStatus.loading);
      expect(titleOf(container), isNull);

      serve(byTab['eggs']!, 'shopA');
      await settle();

      expect(container.read(activeTabKeyProvider), 'eggs');
      expect(container.read(activeSectionsProvider).status, SectionsStatus.ready);
      expect(titleOf(container), 'shopA:eggs:retail');
      // Stale tabs were never cached by their aborted requests.
      final SectionKey chicken = container
          .read(storefrontScopeProvider)
          .sectionKey('chicken');
      expect(
        HiveService.sectionManifestBox.containsKey(LayoutDiskStore.sectionKeyOf(chicken)),
        isFalse,
      );
    });

    test('taps spaced one event-loop turn apart: every superseded request that '
        'reached the wire is aborted; only Eggs survives', () async {
      await loadShopA();
      final int requestsBefore = env.adapter.requests.length;
      final tab = container.read(selectedCategoryIdProvider.notifier);

      for (final String key in <String>['chicken', 'fish', 'mutton', 'eggs']) {
        tab.select(key);
        container.read(activeSectionsProvider);
        await settle(); // let the request actually be dispatched
      }

      final List<FakeRequest> issued = env.adapter.requests
          .skip(requestsBefore)
          .where((r) => r.tabKey != null)
          .toList();
      expect(
        issued.map((r) => r.tabKey).toList(),
        <String?>['chicken', 'fish', 'mutton', 'eggs'],
        reason: 'each tab really did start a request',
      );
      for (final FakeRequest r in issued.take(3)) {
        expect(r.cancelled, isTrue, reason: '${r.tabKey} was superseded');
      }
      expect(issued.last.cancelled, isFalse);

      // Deliver everything, oldest first — the late ones must be ignored.
      for (final FakeRequest r in issued) {
        serve(r, 'shopA');
      }
      await settle();
      expect(container.read(activeTabKeyProvider), 'eggs');
      expect(container.read(activeSectionsProvider).status, SectionsStatus.ready);
      expect(titleOf(container), 'shopA:eggs:retail');
      for (final String stale in <String>['chicken', 'fish', 'mutton']) {
        expect(
          HiveService.sectionManifestBox.containsKey(
            LayoutDiskStore.sectionKeyOf(
              container.read(storefrontScopeProvider).sectionKey(stale),
            ),
          ),
          isFalse,
          reason: '$stale was aborted and must not have been cached',
        );
      }
    });

    test('returning to a loaded tab is instant: no loading state, no request',
        () async {
      await loadShopA();
      final tab = container.read(selectedCategoryIdProvider.notifier);

      tab.select('fish');
      await settle();
      serve(env.adapter.lastWhere((r) => r.tabKey == 'fish'), 'shopA');
      await settle();
      expect(titleOf(container), 'shopA:fish:retail');

      final int requests = env.adapter.requests.length;
      final List<SectionsStatus> seen = <SectionsStatus>[];
      container.listen<ActiveSections>(
        activeSectionsProvider,
        (_, ActiveSections s) => seen.add(s.status),
      );

      tab.select('all'); // loaded earlier
      // Available on the very first read after the switch — synchronously.
      expect(container.read(activeSectionsProvider).status, SectionsStatus.ready);
      expect(titleOf(container), 'shopA:all:retail');
      await settle();

      expect(seen, isNot(contains(SectionsStatus.loading)));
      expect(env.adapter.requests.length, requests,
          reason: 'content is fresh, so no revalidation request is made');
    });
  });

  group('store / location switching is atomic', () {
    test('Store A → Store B: nothing of A is readable while B loads, then B '
        'renders consistently; A is still cached', () async {
      await loadShopA();
      expect(titleOf(container), 'shopA:all:retail');
      expect(
        container.read(activeTabThemeProvider).sections.topBar.backgroundColor.toARGB32(),
        0xFFD32F2F,
      );
      final int requests = env.adapter.requests.length;

      await AppCacheManager.setShopScope(<String>['shopB']);
      await settle();

      // Never A's theme/tabs/sections/products under B.
      expect(container.read(themeReadyProvider), isFalse);
      expect(container.read(themeTabsProvider), isNull);
      expect(container.read(activeSectionsProvider).status, SectionsStatus.loading);
      expect(titleOf(container), isNull);
      expect(
        container.read(activeTabThemeProvider).sections.topBar.backgroundColor.toARGB32(),
        0xFFFFFFFF,
      );

      for (final FakeRequest r in env.adapter.requests.skip(requests).toList()) {
        serve(r, 'shopB');
      }
      await settle();

      expect(container.read(themeReadyProvider), isTrue);
      expect(
        container.read(activeTabThemeProvider).sections.topBar.backgroundColor.toARGB32(),
        0xFF1B5E20,
      );
      expect(titleOf(container), 'shopB:all:retail');

      // Back to A: served from A's own cache, instantly, and still A's.
      final int afterB = env.adapter.requests.length;
      await AppCacheManager.setShopScope(<String>['shopA']);
      await settle();
      expect(container.read(themeReadyProvider), isTrue);
      expect(titleOf(container), 'shopA:all:retail');
      expect(
        container.read(activeTabThemeProvider).sections.topBar.backgroundColor.toARGB32(),
        0xFFD32F2F,
      );
      expect(env.adapter.requests.length, afterB,
          reason: 'A was still fresh in cache');
    });

    test('a shop switch while requests are in flight cannot let A land in B',
        () async {
      await settle();
      final List<FakeRequest> aRequests = env.adapter.pending.toList();
      await AppCacheManager.setShopScope(<String>['shopB']);
      await settle();
      for (final FakeRequest r in aRequests) {
        serve(r, 'shopA'); // late A responses (aborted, but even if delivered)
      }
      await settle();

      expect(container.read(themeReadyProvider), isFalse);
      expect(titleOf(container), isNull);
      for (final FakeRequest r in env.adapter.pending.toList()) {
        serve(r, 'shopB');
      }
      await settle();
      expect(titleOf(container), 'shopB:all:retail');
    });
  });

  group('B2C ↔ B2B', () {
    test('switches price-mode data without touching the theme, and both modes '
        'stay cached', () async {
      await loadShopA();
      final int themeRequests = env.adapter.count((r) => r.isTheme);
      expect(titleOf(container), 'shopA:all:retail');

      await container.read(priceModeProvider.notifier).toggle();
      await settle();

      // Theme is mode-independent: still ready, not re-requested.
      expect(container.read(themeReadyProvider), isTrue);
      expect(env.adapter.count((r) => r.isTheme), themeRequests);
      // Sections are mode-specific: loading for wholesale until it arrives.
      expect(container.read(storefrontScopeProvider).priceMode, 'wholesale');
      expect(container.read(activeSectionsProvider).status, SectionsStatus.loading);
      final FakeRequest wholesale = env.adapter.pending.single;
      expect(wholesale.query['priceMode'], 'wholesale');
      serve(wholesale, 'shopA');
      await settle();
      expect(titleOf(container), 'shopA:all:wholesale');

      final int requests = env.adapter.requests.length;
      await container.read(priceModeProvider.notifier).toggle();
      await settle();
      expect(titleOf(container), 'shopA:all:retail');
      expect(env.adapter.requests.length, requests,
          reason: 'retail content was kept and is still fresh');
    });
  });

  group('kill and reopen', () {
    test('the restored cache belongs to the restored scope only', () async {
      await loadShopA();
      await waitUntil(
        () => HiveService.sectionManifestBox.length >= 1 &&
            HiveService.remoteThemeBox.length >= 1,
      );
      final int aRequests = env.adapter.requests.length;

      for (final ProviderSubscription<Object?> s in keepAlive) {
        s.close();
      }
      keepAlive.clear();
      container.dispose();
      await env.killApp();
      await env.reopenApp();

      final ProviderContainer reopened = env.container();
      addTearDown(reopened.dispose);
      watchVisible(reopened);

      // Same scope restored from disk: content is there on the FIRST read.
      expect(AppCacheManager.currentShopScope, 'shopA');
      expect(reopened.read(themeReadyProvider), isTrue);
      expect(reopened.read(activeSectionsProvider).status, SectionsStatus.ready);
      expect(titleOf(reopened), 'shopA:all:retail');
      expect(
        reopened.read(activeTabThemeProvider).sections.topBar.backgroundColor.toARGB32(),
        0xFFD32F2F,
      );

      // ...and is revalidated in the background (it is treated as stale).
      await settle();
      final List<FakeRequest> revalidations =
          env.adapter.requests.skip(aRequests).toList();
      expect(revalidations, isNotEmpty);
      expect(revalidations.first.ifNoneMatch, isNotNull);
      for (final FakeRequest r in revalidations) {
        r.respondNotModified();
      }
      await settle();
      expect(titleOf(reopened), 'shopA:all:retail');

      // A different persisted scope must not surface A's data.
      await AppCacheManager.setShopScope(<String>['shopB']);
      await settle();
      expect(reopened.read(themeReadyProvider), isFalse);
      expect(titleOf(reopened), isNull);
    });

    test('a scope that was never cached shows nothing on reopen', () async {
      await loadShopA();
      await waitUntil(() => HiveService.sectionManifestBox.length >= 1);
      await HiveService.settingsBox.put(
        'bakaloo_app_cache_shop_scope',
        'shopZ', // the user relocated before the app was killed
      );
      for (final ProviderSubscription<Object?> s in keepAlive) {
        s.close();
      }
      keepAlive.clear();
      container.dispose();
      await env.killApp();
      await env.reopenApp();

      final ProviderContainer reopened = env.container();
      addTearDown(reopened.dispose);
      watchVisible(reopened);

      expect(AppCacheManager.currentShopScope, 'shopZ');
      expect(reopened.read(themeReadyProvider), isFalse);
      expect(titleOf(reopened), isNull);
    });
  });

  group('prefetch', () {
    test('warms the neighbouring tabs once the active tab is stable', () async {
      await loadShopA();
      keepAlive.add(container.listen(storefrontPrefetchProvider, (_, __) {}));
      env.adapter.autoRespond = (FakeRequest r) => serve(r, 'shopA');
      final int before = env.adapter.requests.length;

      await Future<void>.delayed(kPrefetchSettleDelay + const Duration(milliseconds: 500));

      final Set<String?> warmed = env.adapter.requests
          .skip(before)
          .map((FakeRequest r) => r.tabKey)
          .toSet();
      expect(warmed, <String?>{'chicken', 'fish'}); // right neighbours of "all"
    });

    test('switching tab before it settles issues no prefetch for the old tab',
        () async {
      await loadShopA();
      keepAlive.add(container.listen(storefrontPrefetchProvider, (_, __) {}));
      final int before = env.adapter.requests.length;

      container.read(selectedCategoryIdProvider.notifier).select('chicken');
      await settle();
      container.read(selectedCategoryIdProvider.notifier).select('fish');
      await settle();

      // Only the visible tabs' own requests; nothing prefetched yet.
      final List<String?> issued = env.adapter.requests
          .skip(before)
          .map((FakeRequest r) => r.tabKey)
          .toList();
      expect(issued.toSet().difference(<String?>{'chicken', 'fish'}), isEmpty);
    });

    test('prefetchOrder: nearest neighbours first, capped, default last', () {
      List<TabThemeEntry> tabs(List<String> keys) => TabThemesResponse.fromJson(
            themePayload(
              storeKey: 'zepto',
              tabKeys: keys,
              topBarColor: kRed,
              defaultTab: 'all',
            )['data'] as Map<String, dynamic>,
          ).tabs;
      expect(prefetchOrder(tabs(kTabs), 'fish'), <String>['mutton', 'chicken', 'eggs']);
      expect(prefetchOrder(tabs(kTabs), 'all'), <String>['chicken', 'fish']);
      expect(prefetchOrder(tabs(kTabs), 'eggs'), <String>['mutton', 'fish', 'all']);
    });
  });

  test('no shop-scoped price mode leaks: scope carries store + shop + mode',
      () async {
    await HiveService.settingsBox.put(StorageKeys.priceMode, 'wholesale');
    final ProviderContainer c = env.container();
    addTearDown(c.dispose);
    final StorefrontScope scope = c.read(storefrontScopeProvider);
    expect(scope.storeKey, 'zepto');
    expect(scope.shopScope, 'shopA');
    expect(scope.priceMode, 'wholesale');
    expect(
      scope.sectionKey('eggs'),
      const SectionKey(
        storeKey: 'zepto',
        shopScope: 'shopA',
        priceMode: 'wholesale',
        tabKey: 'eggs',
      ),
    );
    expect(c.read(selectedStoreProvider).id, 'zepto');
  });
}
