import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/core/providers/storefront_scope_provider.dart';
import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/core/theme/layout_flight.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_provider.dart';

import 'theme_test_harness.dart';

void main() {
  late ThemeTestEnv env;

  const SectionScopeKey retailA = SectionScopeKey(
    storeKey: 'zepto',
    shopScope: 'shopA',
    priceMode: 'retail',
    tabKey: 'chicken',
  );

  Map<String, dynamic> body(String title) =>
      sectionsPayload(storeKey: 'zepto', tabKey: 'chicken', title: title);

  setUp(() async {
    env = await ThemeTestEnv.create();
  });
  tearDown(() => env.dispose());

  group('cache keys are captured when the request STARTS', () {
    test('a response requested under shop A is never stored under shop B',
        () async {
      await AppCacheManager.setShopScope(<String>['shopA']);
      final LayoutClaim<Object?> claim = claimSections(retailA);
      await settle();

      // The customer moves to another shop while the request is in flight.
      await AppCacheManager.setShopScope(<String>['shopB']);
      env.adapter.pending.single.respondJson(body('Shop A chicken'));
      final FetchOutcome<Object?> outcome = await claim.result;
      expect(outcome.status, FetchStatus.updated);

      const SectionScopeKey asShopB = SectionScopeKey(
        storeKey: 'zepto',
        shopScope: 'shopB',
        priceMode: 'retail',
        tabKey: 'chicken',
      );
      expect(peekSections(asShopB), isNull);
      expect(peekSections(retailA), isNotNull);
      expect(
        HiveService.sectionManifestBox
            .keys
            .cast<String>()
            .map(AppCacheManager.scopeOfKey)
            .toSet(),
        <String?>{'shopA'},
      );
    });

    test('a retail response is never stored as wholesale after a B2B switch',
        () async {
      final LayoutClaim<Object?> claim = claimSections(retailA);
      await settle();
      final FakeRequest request = env.adapter.pending.single;
      expect(request.query['priceMode'], 'retail',
          reason: 'price mode is sent explicitly, not left to the interceptor');

      await env.setPriceModeSetting('wholesale');
      request.respondJson(body('Retail'));
      await claim.result;

      expect(
        peekSections(const SectionScopeKey(
          storeKey: 'zepto',
          shopScope: 'shopA',
          priceMode: 'wholesale',
          tabKey: 'chicken',
        )),
        isNull,
      );
      expect(peekSections(retailA), isNotNull);
    });
  });

  group('shared flights and cancellation', () {
    test('identical requests share one network call', () async {
      final LayoutClaim<Object?> a = claimSections(retailA);
      final LayoutClaim<Object?> b = claimSections(retailA);
      await settle();
      expect(env.adapter.requests, hasLength(1));
      env.adapter.pending.single.respondJson(body('X'));
      expect((await a.result).status, FetchStatus.updated);
      expect((await b.result).held, isNotNull);
    });

    test('a shared request is aborted only when its LAST claimant releases',
        () async {
      final LayoutClaim<Object?> a = claimSections(retailA);
      final LayoutClaim<Object?> b = claimSections(retailA);
      await settle();
      final FakeRequest request = env.adapter.requests.single;

      a.release();
      await settle();
      expect(request.cancelled, isFalse, reason: 'b still needs it');
      b.release();
      await settle();
      expect(request.cancelled, isTrue);
      expect((await b.result).status, FetchStatus.cancelled);
    });

    test('a request after a cancelled one starts a fresh network call',
        () async {
      final LayoutClaim<Object?> first = claimSections(retailA);
      await settle();
      first.release();
      final LayoutClaim<Object?> second = claimSections(retailA);
      await settle();
      expect(env.adapter.requests, hasLength(2));
      env.adapter.requests.last.respondJson(body('Fresh'));
      expect((await second.result).status, FetchStatus.updated);
    });
  });

  group('revalidation', () {
    Future<void> seed() async {
      final LayoutClaim<Object?> c = claimSections(retailA);
      await settle();
      env.adapter.pending.single.respondJson(
        body('One'),
        headers: <String, List<String>>{
          'etag': <String>['"v1"'],
        },
      );
      await c.result;
    }

    test('sends If-None-Match; 304 means "nothing changed" and no signal',
        () async {
      await seed();
      final List<String> signals = <String>[];
      layoutChanges.stream.listen(signals.add);

      final LayoutClaim<Object?> c = claimSections(retailA);
      await settle();
      expect(env.adapter.pending.single.ifNoneMatch, '"v1"');
      env.adapter.pending.single.respondNotModified();
      expect((await c.result).status, FetchStatus.notModified);
      expect(signals, isEmpty);
    });

    test('identical bytes without an ETag produce no change signal', () async {
      await seed();
      final List<String> signals = <String>[];
      layoutChanges.stream.listen(signals.add);
      final LayoutClaim<Object?> c = claimSections(retailA);
      await settle();
      env.adapter.pending.single.respondJson(body('One'));
      expect((await c.result).status, FetchStatus.notModified);
      expect(signals, isEmpty);
    });

    test('changed content signals exactly its own key, once', () async {
      await seed();
      final List<String> signals = <String>[];
      layoutChanges.stream.listen(signals.add);
      final LayoutClaim<Object?> c = claimSections(retailA);
      await settle();
      env.adapter.pending.single.respondJson(body('Two'));
      await c.result;
      expect(signals, <String>[sectionChangeId(retailA)]);
    });

    test('a failed fetch keeps the held snapshot and never blanks it',
        () async {
      await seed();
      final Object before = peekSections(retailA)!.data;
      final LayoutClaim<Object?> c = claimSections(retailA);
      await settle();
      env.adapter.pending.single.fail();
      expect((await c.result).status, FetchStatus.unavailable);
      expect(identical(peekSections(retailA)!.data, before), isTrue);
    });

    test('a 5xx with nothing held is "unavailable", never an empty manifest',
        () async {
      final LayoutClaim<Object?> c = claimSections(retailA);
      await settle();
      env.adapter.pending.single.respondJson(<String, dynamic>{}, status: 503);
      final FetchOutcome<Object?> outcome = await c.result;
      expect(outcome.status, FetchStatus.unavailable);
      expect(outcome.held, isNull);
      expect(peekSections(retailA), isNull);
    });

    test('deferCommit holds the result until commit()', () async {
      final LayoutClaim<Object?> c = claimSections(retailA, deferCommit: true);
      await settle();
      env.adapter.pending.single.respondJson(body('Held'));
      final FetchOutcome<Object?> outcome = await c.result;
      expect(peekSections(retailA), isNull);
      outcome.commit();
      expect(peekSections(retailA), isNotNull);
      outcome.commit(); // idempotent
    });
  });

  group('persistence', () {
    test('the disk envelope round-trips', () {
      final String encoded = encodeLayoutEnvelope(
        raw: '{"a":1}',
        savedAt: DateTime.fromMillisecondsSinceEpoch(1234),
        etag: '"e"',
      );
      final decoded = decodeLayoutEnvelope(encoded)!;
      expect(decoded.raw, '{"a":1}');
      expect(decoded.etag, '"e"');
      expect(decodeLayoutEnvelope('nonsense'), isNull);
      expect(
        decodeLayoutEnvelope(
          encodeLayoutEnvelope(raw: '{}', savedAt: DateTime.now()),
        )!
            .etag,
        isNull,
      );
    });

    test('content restored from disk is served at once but treated as stale',
        () async {
      final LayoutClaim<Object?> c = claimSections(retailA);
      await settle();
      env.adapter.pending.single.respondJson(body('Saved'));
      await c.result;
      await waitUntil(() => HiveService.sectionManifestBox.isNotEmpty);

      resetLayoutMemoryForTests(); // a "new process": empty memory, same disk
      env.adapter.requests.clear();
      final held = peekSections(retailA);
      expect(held, isNotNull);
      expect(held!.isFresh, isFalse);
    });

    test('markStale keeps content visible but forces revalidation', () async {
      final LayoutClaim<Object?> c = claimSections(retailA);
      await settle();
      env.adapter.pending.single.respondJson(body('T'));
      await c.result;
      expect(peekSections(retailA)!.isFresh, isTrue);

      markSectionsStale(storeKey: 'zepto', tabKey: 'chicken');
      expect(peekSections(retailA), isNotNull);
      expect(peekSections(retailA)!.isFresh, isFalse);

      markSectionsStale(storeKey: 'other');
      expect(peekSections(retailA), isNotNull);
    });

    test('scopes beyond the retained few are pruned from disk', () async {
      for (int i = 0; i < 6; i++) {
        await HiveService.sectionManifestBox.put(
          AppCacheManager.scopedKey('layout_sections_v3',
              shopScope: 'shop$i', extra: 'zepto|retail|all'),
          'v3\n0\n\n{}',
        );
        await AppCacheManager.setShopScope(<String>['shop$i']);
      }
      final Set<String?> kept = HiveService.sectionManifestBox.keys
          .cast<String>()
          .map(AppCacheManager.scopeOfKey)
          .toSet();
      expect(kept, <String?>{'shop2', 'shop3', 'shop4', 'shop5'});
    });
  });

  test('theme claims use their own key and query the store', () async {
    const ThemeScopeKey key =
        ThemeScopeKey(storeKey: 'zepto', shopScope: 'shopA');
    final LayoutClaim<Object?> c = claimTheme(key);
    await settle();
    expect(env.adapter.pending.single.query['store_key'], 'zepto');
    env.adapter.pending.single.respondJson(
      themePayload(
        storeKey: 'zepto',
        tabKeys: <String>['all'],
        topBarColor: '#D32F2F',
      ),
    );
    await c.result;
    expect(peekTheme(key), isNotNull);
    expect(
      peekTheme(const ThemeScopeKey(storeKey: 'zepto', shopScope: 'shopB')),
      isNull,
    );
  });
}
