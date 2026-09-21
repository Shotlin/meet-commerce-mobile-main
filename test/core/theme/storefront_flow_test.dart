import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';
import 'package:bakaloo_flutter_app/core/providers/price_mode_provider.dart';
import 'package:bakaloo_flutter_app/core/providers/storefront_scope_provider.dart';
import 'package:bakaloo_flutter_app/core/providers/store_provider.dart';
import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/core/theme/layout_flight.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_provider.dart';

import 'theme_test_harness.dart';

const String kRed = '#D32F2F'; // shop A — the FreshCuts theme
const String kGreen = '#1B5E20'; // shop B
const int kLegacyZeptoBlue = 0xFF88D4FE;
const List<String> kTabs = <String>['all', 'chicken', 'fish', 'mutton', 'eggs'];

String colorFor(String shop) => shop == 'shopB' ? kGreen : kRed;

/// Answers a request the way the real backend would for [shop].
void serve(FakeRequest r, String shop) {
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
  if (r.homeTabKey != null) {
    r.respondJson(tabHomePayload(storeKey: 'zepto', tabKey: r.homeTabKey!));
    return;
  }
  final String tab = r.tabKey!;
  final String mode = r.query['priceMode'] as String;
  r.respondJson(
    sectionsPayload(storeKey: 'zepto', tabKey: tab, title: '$shop:$tab:$mode'),
    headers: <String, List<String>>{
      'etag': <String>['"sec-$shop-$tab-$mode"'],
    },
  );
}

int topBar(ProviderContainer c) =>
    c.read(activeTabThemeProvider).sections.topBar.backgroundColor.toARGB32();

String? titleOf(ProviderContainer c) {
  final sections = c.read(activeSectionManifestProvider).sections;
  return sections.isEmpty ? null : sections.first.config['title'] as String?;
}

void main() {
  late ThemeTestEnv env;
  late ProviderContainer container;
  final List<ProviderSubscription<Object?>> keepAlive =
      <ProviderSubscription<Object?>>[];

  /// What the visible widgets watch; the tests keep the same providers alive.
  void watchVisible(ProviderContainer c) {
    keepAlive
      ..add(c.listen(activeSectionManifestProvider, (_, __) {}))
      ..add(c.listen(activeSectionsStatusProvider, (_, __) {}))
      ..add(c.listen(activeTabThemeProvider, (_, __) {}))
      ..add(c.listen(tabThemesProvider, (_, __) {}));
  }

  void closeAll() {
    for (final ProviderSubscription<Object?> s in keepAlive) {
      s.close();
    }
    keepAlive.clear();
  }

  setUp(() async {
    env = await ThemeTestEnv.create();
    await AppCacheManager.setShopScope(<String>['shopA']);
    container = env.container();
    watchVisible(container);
  });

  tearDown(() async {
    closeAll();
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
    test('a neutral placeholder — never the legacy Zepto theme — then the '
        'Theme Builder theme', () async {
      final List<int> colors = <int>[];
      container.listen<RemoteTheme>(
        activeTabThemeProvider,
        (_, RemoteTheme t) =>
            colors.add(t.sections.topBar.backgroundColor.toARGB32()),
        fireImmediately: true,
      );
      await settle();

      expect(container.read(themeResolvedProvider), isFalse);
      expect(container.read(tabThemesSnapshotProvider), isNull);
      expect(container.read(activeSectionsStatusProvider), SectionsStatus.loading);
      expect(colors.single, 0xFFFFFFFF, reason: 'neutral, not any store theme');

      for (final FakeRequest r in env.adapter.pending.toList()) {
        serve(r, 'shopA');
      }
      await settle();

      expect(container.read(themeResolvedProvider), isTrue);
      expect(colors.last, 0xFFD32F2F);
      expect(colors, isNot(contains(kLegacyZeptoBlue)));
      expect(container.read(activeSectionsStatusProvider), SectionsStatus.ready);
      expect(titleOf(container), 'shopA:all:retail');
      expect(container.read(tabThemesSnapshotProvider)!.tabs.map((t) => t.tabKey),
          kTabs);
    });

    test('a failed first load is an error state, never a bundled default theme',
        () async {
      await settle();
      for (final FakeRequest r in env.adapter.pending.toList()) {
        r.fail();
      }
      await settle();

      expect(container.read(themeResolvedProvider), isFalse);
      expect(container.read(activeSectionsStatusProvider), SectionsStatus.failed);
      expect(env.unavailableReports, greaterThan(0));
      expect(topBar(container), isNot(kLegacyZeptoBlue));
    });
  });

  group('rapid tab switching', () {
    test('All → Chicken → Fish → Mutton → Eggs (no pause): Eggs wins, stale '
        'requests are aborted, no endless loader', () async {
      await loadShopA();
      final int before = env.adapter.requests.length;
      final tab = container.read(selectedCategoryIdProvider.notifier);
      for (final String key in <String>['chicken', 'fish', 'mutton', 'eggs']) {
        tab.select(key);
        expect(container.read(activeTabKeyProvider), key);
        container.read(activeSectionManifestProvider);
      }
      await settle();

      final Map<String?, FakeRequest> byTab = <String?, FakeRequest>{
        for (final FakeRequest r
            in env.adapter.requests.skip(before).where((r) => r.tabKey != null))
          r.tabKey: r,
      };
      expect(byTab.containsKey('eggs'), isTrue);
      for (final String stale in <String>['chicken', 'fish', 'mutton']) {
        if (byTab.containsKey(stale)) {
          expect(byTab[stale]!.cancelled, isTrue, reason: '$stale is stale');
        }
      }
      expect(
        env.adapter.pending.where((r) => r.tabKey != null).map((r) => r.tabKey),
        <String?>['eggs'],
        reason: 'exactly one section request is still alive: the latest',
      );
      expect(container.read(activeSectionsStatusProvider), SectionsStatus.loading);

      // Late responses for superseded tabs must change nothing.
      for (final String stale in <String>['chicken', 'fish', 'mutton']) {
        if (byTab.containsKey(stale)) serve(byTab[stale]!, 'shopA');
      }
      await settle();
      expect(container.read(activeSectionsStatusProvider), SectionsStatus.loading);
      expect(titleOf(container), isNull);

      serve(byTab['eggs']!, 'shopA');
      await settle();
      expect(container.read(activeTabKeyProvider), 'eggs');
      expect(container.read(activeSectionsStatusProvider), SectionsStatus.ready);
      expect(titleOf(container), 'shopA:eggs:retail');
      expect(peekSections(container.read(activeSectionKeyProvider).tabKeyCopy('chicken')),
          isNull);
    });

    test('taps one event-loop turn apart: every superseded request that '
        'reached the wire is aborted; only Eggs survives', () async {
      await loadShopA();
      final int before = env.adapter.requests.length;
      final tab = container.read(selectedCategoryIdProvider.notifier);
      for (final String key in <String>['chicken', 'fish', 'mutton', 'eggs']) {
        tab.select(key);
        container.read(activeSectionManifestProvider);
        await settle();
      }
      final List<FakeRequest> issued = env.adapter.requests
          .skip(before)
          .where((r) => r.tabKey != null)
          .toList();
      expect(issued.map((r) => r.tabKey).toList(),
          <String?>['chicken', 'fish', 'mutton', 'eggs']);
      for (final FakeRequest r in issued.take(3)) {
        expect(r.cancelled, isTrue, reason: '${r.tabKey} was superseded');
      }
      expect(issued.last.cancelled, isFalse);

      for (final FakeRequest r in issued) {
        serve(r, 'shopA'); // oldest first — the late ones must be ignored
      }
      await settle();
      expect(titleOf(container), 'shopA:eggs:retail');
      for (final String stale in <String>['chicken', 'fish', 'mutton']) {
        expect(
          peekSections(
              container.read(storefrontScopeProvider).sectionKey(stale)),
          isNull,
          reason: '$stale was aborted and must not be cached',
        );
      }
    });

    test('returning to a loaded tab is instant: ready on the first read, no '
        'request', () async {
      await loadShopA();
      final tab = container.read(selectedCategoryIdProvider.notifier);
      tab.select('fish');
      await settle();
      serve(env.adapter.requests.lastWhere((r) => r.tabKey == 'fish'), 'shopA');
      await settle();
      expect(titleOf(container), 'shopA:fish:retail');

      final int requests = env.adapter.requests.length;
      final List<SectionsStatus> seen = <SectionsStatus>[];
      container.listen<SectionsStatus>(
          activeSectionsStatusProvider, (_, s) => seen.add(s));

      tab.select('all');
      expect(container.read(activeSectionsStatusProvider), SectionsStatus.ready);
      expect(titleOf(container), 'shopA:all:retail');
      await settle();
      expect(seen, isNot(contains(SectionsStatus.loading)));
      expect(env.adapter.requests.length, requests,
          reason: 'content is fresh, so no revalidation request is made');
    });
  });

  group('store / location switching is atomic', () {
    test('Store A → Store B: nothing of A is readable while B loads, then B '
        'renders consistently; A stays cached', () async {
      await loadShopA();
      expect(titleOf(container), 'shopA:all:retail');
      expect(topBar(container), 0xFFD32F2F);
      final int requests = env.adapter.requests.length;

      await AppCacheManager.setShopScope(<String>['shopB']);
      await settle();

      expect(container.read(themeResolvedProvider), isFalse);
      expect(container.read(tabThemesSnapshotProvider), isNull);
      expect(container.read(activeSectionsStatusProvider), SectionsStatus.loading);
      expect(titleOf(container), isNull);
      expect(topBar(container), 0xFFFFFFFF);

      for (final FakeRequest r in env.adapter.requests.skip(requests).toList()) {
        serve(r, 'shopB');
      }
      await settle();
      expect(container.read(themeResolvedProvider), isTrue);
      expect(topBar(container), 0xFF1B5E20);
      expect(titleOf(container), 'shopB:all:retail');

      final int afterB = env.adapter.requests.length;
      await AppCacheManager.setShopScope(<String>['shopA']);
      await settle();
      expect(topBar(container), 0xFFD32F2F);
      expect(titleOf(container), 'shopA:all:retail');
      expect(env.adapter.requests.length, afterB, reason: 'A was still fresh');
    });

    test('a shop switch with requests in flight cannot let A land in B',
        () async {
      await settle();
      final List<FakeRequest> aRequests = env.adapter.pending.toList();
      await AppCacheManager.setShopScope(<String>['shopB']);
      await settle();
      expect(aRequests.every((r) => r.cancelled), isTrue,
          reason: "shop A's in-flight theme + sections requests are aborted");
      for (final FakeRequest r in aRequests) {
        serve(r, 'shopA'); // late A responses
      }
      await settle();
      expect(container.read(themeResolvedProvider), isFalse);
      expect(titleOf(container), isNull);
      for (final FakeRequest r in env.adapter.pending.toList()) {
        serve(r, 'shopB');
      }
      await settle();
      expect(titleOf(container), 'shopB:all:retail');
    });
  });

  group('B2C ↔ B2B', () {
    test('switches price-mode data without touching the theme; both modes '
        'stay cached', () async {
      await loadShopA();
      final int themeRequests = env.adapter.count((r) => r.isTheme);

      await container.read(priceModeProvider.notifier).toggle();
      await settle();

      expect(container.read(themeResolvedProvider), isTrue);
      expect(env.adapter.count((r) => r.isTheme), themeRequests);
      expect(container.read(storefrontScopeProvider).priceMode, 'wholesale');
      expect(container.read(activeSectionsStatusProvider), SectionsStatus.loading);
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
      await waitUntil(() =>
          HiveService.sectionManifestBox.isNotEmpty &&
          HiveService.remoteThemeBox.isNotEmpty);
      final int aRequests = env.adapter.requests.length;

      closeAll();
      container.dispose();
      await env.killAndReopenApp();

      final ProviderContainer reopened = env.container();
      addTearDown(reopened.dispose);
      watchVisible(reopened);

      expect(AppCacheManager.currentShopScope, 'shopA');
      expect(reopened.read(themeResolvedProvider), isTrue);
      expect(reopened.read(activeSectionsStatusProvider), SectionsStatus.ready);
      expect(titleOf(reopened), 'shopA:all:retail');
      expect(topBar(reopened), 0xFFD32F2F);

      await settle(); // disk content is stale => revalidated in the background
      final List<FakeRequest> revalidations =
          env.adapter.requests.skip(aRequests).toList();
      expect(revalidations, isNotEmpty);
      expect(revalidations.first.ifNoneMatch, isNotNull);
      for (final FakeRequest r in revalidations) {
        r.respondNotModified();
      }
      await settle();
      expect(titleOf(reopened), 'shopA:all:retail');

      await AppCacheManager.setShopScope(<String>['shopB']);
      await settle();
      expect(reopened.read(themeResolvedProvider), isFalse);
      expect(titleOf(reopened), isNull);
    });

    test('a persisted scope that was never cached shows nothing on reopen',
        () async {
      await loadShopA();
      await waitUntil(() => HiveService.sectionManifestBox.isNotEmpty);
      await HiveService.settingsBox
          .put('bakaloo_app_cache_shop_scope', 'shopZ');
      closeAll();
      container.dispose();
      await env.killAndReopenApp();

      final ProviderContainer reopened = env.container();
      addTearDown(reopened.dispose);
      watchVisible(reopened);
      expect(AppCacheManager.currentShopScope, 'shopZ');
      expect(reopened.read(themeResolvedProvider), isFalse);
      expect(titleOf(reopened), isNull);
    });
  });

  group('tab-home content follows the same scope', () {
    test('re-keys on a shop switch and aborts the previous shop\'s request',
        () async {
      await loadShopA();
      keepAlive.add(container.listen(selectedTabHomeContentProvider, (_, __) {}));
      await settle();
      final FakeRequest aHome =
          env.adapter.pending.firstWhere((r) => r.homeTabKey != null);
      expect(aHome.query['priceMode'], 'retail');

      await AppCacheManager.setShopScope(<String>['shopB']);
      await settle();
      expect(aHome.cancelled, isTrue);
    });
  });

  group('no refetch loops', () {
    test('a dashboard change refetches theme + active tab exactly once, '
        'commits them together, and then nothing further happens', () async {
      await loadShopA();
      final int before = env.adapter.requests.length;
      final List<String> signals = <String>[];
      layoutChanges.stream.listen(signals.add);

      markThemeStale(storeKey: 'zepto');
      markSectionsStale(storeKey: 'zepto');
      final Future<void> refresh =
          container.read(storefrontSyncProvider).revalidateActive();
      await settle();

      final List<FakeRequest> refetch =
          env.adapter.requests.skip(before).toList();
      expect(refetch.where((r) => r.isTheme), hasLength(1));
      expect(refetch.where((r) => r.tabKey == 'all'), hasLength(1));

      // Theme lands first: nothing is applied until the sections arrive too.
      serve(refetch.firstWhere((r) => r.isTheme), 'shopB');
      await settle();
      expect(signals, isEmpty, reason: 'held so both land in one frame');
      expect(topBar(container), 0xFFD32F2F);

      serve(refetch.firstWhere((r) => r.tabKey == 'all'), 'shopB');
      await refresh;
      await settle();
      expect(signals, hasLength(2));
      expect(topBar(container), 0xFF1B5E20);
      expect(titleOf(container), 'shopB:all:retail');

      // Applying the change must not trigger any further request.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(env.adapter.requests.length, before + 2);
    });
  });

  group('prefetch', () {
    test('warms the neighbouring tabs once the active tab is stable', () async {
      await loadShopA();
      keepAlive.add(container.listen(storefrontPrefetchProvider, (_, __) {}));
      env.adapter.autoRespond = (FakeRequest r) => serve(r, 'shopA');
      final int before = env.adapter.requests.length;
      await Future<void>.delayed(
          kPrefetchSettleDelay + const Duration(milliseconds: 500));
      final Set<String?> warmed =
          env.adapter.requests.skip(before).map((r) => r.tabKey).toSet();
      expect(warmed, <String?>{'chicken', 'fish'});
    });

    test('switching tab before it settles issues no prefetch for the old tab',
        () async {
      await loadShopA();
      keepAlive.add(container.listen(storefrontPrefetchProvider, (_, __) {}));
      final int before = env.adapter.requests.length;
      final tab = container.read(selectedCategoryIdProvider.notifier);
      tab.select('chicken');
      container.read(activeSectionManifestProvider);
      await settle();
      tab.select('fish');
      container.read(activeSectionManifestProvider);
      await settle();
      final Set<String?> issued =
          env.adapter.requests.skip(before).map((r) => r.tabKey).toSet();
      expect(issued.difference(<String?>{'chicken', 'fish'}), isEmpty);
    });

    test('prefetchOrder: nearest neighbours first, capped, default last', () {
      List<TabThemeEntry> tabs(List<String> keys) => TabThemesResponse.fromJson(
            themePayload(
              storeKey: 'zepto',
              tabKeys: keys,
              topBarColor: kRed,
            )['data'] as Map<String, dynamic>,
          ).tabs;
      expect(prefetchOrder(tabs(kTabs), 'fish'), <String>['mutton', 'chicken', 'eggs']);
      expect(prefetchOrder(tabs(kTabs), 'all'), <String>['chicken', 'fish']);
      expect(prefetchOrder(tabs(kTabs), 'eggs'), <String>['mutton', 'fish', 'all']);
    });
  });

  test('the scope carries store + shop + price mode', () async {
    await HiveService.settingsBox.put(StorageKeys.priceMode, 'wholesale');
    final ProviderContainer c = env.container();
    addTearDown(c.dispose);
    final StorefrontScope scope = c.read(storefrontScopeProvider);
    expect(scope.storeKey, 'zepto');
    expect(scope.shopScope, 'shopA');
    expect(scope.priceMode, 'wholesale');
    expect(c.read(selectedStoreProvider).id, 'zepto');
  });
}

extension on SectionScopeKey {
  SectionScopeKey tabKeyCopy(String tab) => SectionScopeKey(
        storeKey: storeKey,
        shopScope: shopScope,
        priceMode: priceMode,
        tabKey: tab,
      );
}
