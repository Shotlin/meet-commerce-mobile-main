import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
import 'package:bakaloo_flutter_app/core/storefront/storefront_sync.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_provider.dart';
import 'package:bakaloo_flutter_app/shared/widgets/category_tabs_row.dart';

import '../core/storefront/storefront_harness.dart';

/// Records what one frame shows: the top-bar colour AND the first section title.
class _Probe extends ConsumerWidget {
  const _Probe(this.builds);

  final List<String> builds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int color = ref.watch(
      activeTabThemeProvider
          .select((t) => t.sections.topBar.backgroundColor.toARGB32()),
    );
    final String title = ref.watch(
      activeSectionsProvider.select(
        (s) => s.sections.isEmpty
            ? '-'
            : s.sections.first.config['title'] as String,
      ),
    );
    ref.watch(storefrontSyncProvider); // as HomeScreen does
    builds.add('${color.toRadixString(16)}|$title');
    return const SizedBox.shrink();
  }
}

/// Dio hops through a few zero-duration timers before a request reaches the
/// adapter; under fake async each one needs a tick.
Future<void> pumpFrames(WidgetTester tester, [int frames = 8]) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
  const List<String> tabs = <String>['all', 'chicken', 'fish'];

  void serveInitial(FakeStorefrontAdapter adapter, {String suffix = 'v1'}) {
    for (final FakeRequest r in adapter.pending.toList()) {
      if (r.isTheme) {
        r.respondJson(
          themePayload(
            storeKey: 'zepto',
            shopId: 'shopA',
            tabKeys: tabs,
            topBarColor: suffix == 'v1' ? '#D32F2F' : '#1B5E20',
          ),
        );
      } else {
        r.respondJson(
          sectionsPayload(
            storeKey: 'zepto',
            tabKey: r.tabKey!,
            title: '$suffix:${r.tabKey}',
          ),
        );
      }
    }
  }

  testWidgets(
      'dashboard theme + section update: the screen goes old→new in ONE frame '
      '(never new chrome with old sections, or the reverse)', (tester) async {
    final StorefrontTestEnv env =
        (await tester.runAsync(StorefrontTestEnv.create))!;
    await tester.runAsync(() => AppCacheManager.setShopScope(<String>['shopA']));
    final ProviderContainer container = env.container(memoryDisk: true);
    final List<String> builds = <String>[];

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _Probe(builds),
      ),
    );
    await pumpFrames(tester);
    serveInitial(env.adapter);
    await pumpFrames(tester);
    expect(builds.last, 'ffd32f2f|v1:all');

    builds.clear();
    env.adapter.requests.clear();

    // The Theme Builder publishes: a theme event and a section event.
    env.themeEvents.add(<String, dynamic>{'storeKey': 'zepto'});
    env.sectionEvents.add(<String, dynamic>{'tab_key': 'all'});
    await tester.pump(kStorefrontSyncDebounce); // coalesced into ONE refresh
    await pumpFrames(tester);

    expect(env.adapter.pending.where((r) => r.isTheme), hasLength(1));
    expect(env.adapter.pending.where((r) => r.tabKey == 'all'), hasLength(1));

    // The theme response lands first — it must NOT be shown on its own.
    env.adapter.pending.firstWhere((r) => r.isTheme).respondJson(
          themePayload(
            storeKey: 'zepto',
            shopId: 'shopA',
            tabKeys: tabs,
            topBarColor: '#1B5E20',
          ),
        );
    await pumpFrames(tester);
    expect(builds, isEmpty, reason: 'held until the sections arrive too');

    env.adapter.pending.firstWhere((r) => r.tabKey == 'all').respondJson(
          sectionsPayload(storeKey: 'zepto', tabKey: 'all', title: 'v2:all'),
        );
    await pumpFrames(tester);

    expect(builds, <String>['ff1b5e20|v2:all'],
        reason: 'exactly one rebuild, already showing the new pair');
    expect(builds, isNot(contains('ff1b5e20|v1:all')));
    expect(builds, isNot(contains('ffd32f2f|v2:all')));

    container.dispose(); // cancels StorefrontSync timers before invariants run
    await tester.runAsync(env.dispose);
  });

  testWidgets('a dashboard event storm makes exactly one refresh, not one per '
      'event', (tester) async {
    final StorefrontTestEnv env =
        (await tester.runAsync(StorefrontTestEnv.create))!;
    await tester.runAsync(() => AppCacheManager.setShopScope(<String>['shopA']));
    final ProviderContainer container = env.container(memoryDisk: true);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _Probe(<String>[]),
      ),
    );
    await pumpFrames(tester);
    serveInitial(env.adapter);
    await pumpFrames(tester);
    env.adapter.requests.clear();

    for (int i = 0; i < 12; i++) {
      env.themeEvents.add(<String, dynamic>{'storeKey': 'zepto'});
      env.sectionEvents.add(<String, dynamic>{'tab_key': 'all'});
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump(kStorefrontSyncDebounce);
    await pumpFrames(tester);

    expect(env.adapter.requests.where((r) => r.isTheme), hasLength(1));
    expect(env.adapter.requests.where((r) => r.tabKey == 'all'), hasLength(1));

    container.dispose();
    await tester.runAsync(env.dispose);
  });

  group('CategoryTabsRow', () {
    Widget host(List<TabThemeEntry>? tabsValue) {
      return ProviderScope(
        overrides: [themeTabsProvider.overrideWithValue(tabsValue)],
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          child: const MaterialApp(
            home: Scaffold(body: CategoryTabsRow()),
          ),
        ),
      );
    }

    const List<String> legacy = <String>[
      'Fruits & Veg',
      'Dairy',
      'Snacks',
      'Beverages',
      'Rice',
      'Bread',
    ];

    void phoneSurface(WidgetTester tester) {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('unresolved theme shows placeholders, never the legacy tabs',
        (tester) async {
      phoneSurface(tester);
      await tester.pumpWidget(host(null));
      await tester.pump();

      for (final String label in legacy) {
        expect(find.text(label), findsNothing);
      }
      expect(find.text('All'), findsNothing);
      expect(find.byType(CategoryTabsRow), findsOneWidget);
    });

    testWidgets('resolved theme shows exactly the Theme Builder tabs',
        (tester) async {
      phoneSurface(tester);
      final List<TabThemeEntry> entries = TabThemesResponse.fromJson(
        themePayload(
          storeKey: 'zepto',
          tabKeys: <String>['all', 'chicken', 'fish', 'mutton', 'eggs'],
          topBarColor: '#D32F2F',
        )['data'] as Map<String, dynamic>,
      ).tabs;
      await tester.pumpWidget(host(entries));
      await tester.pump();

      for (final String label in <String>[
        'All',
        'Chicken',
        'Fish',
        'Mutton',
        'Eggs',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      for (final String label in legacy) {
        expect(find.text(label), findsNothing);
      }
    });
  });
}
