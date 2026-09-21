import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/core/storefront/layout_disk_store.dart';
import 'package:bakaloo_flutter_app/core/storefront/layout_keys.dart';
import 'package:bakaloo_flutter_app/core/storefront/layout_repository.dart';

import 'storefront_harness.dart';

void main() {
  late StorefrontTestEnv env;
  late StorefrontLayoutRepository repo;

  const SectionKey retailA = SectionKey(
    storeKey: 'zepto',
    shopScope: 'shopA',
    priceMode: 'retail',
    tabKey: 'chicken',
  );

  setUp(() async {
    env = await StorefrontTestEnv.create();
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'))
      ..httpClientAdapter = env.adapter;
    repo = StorefrontLayoutRepository(dio: dio);
  });

  tearDown(() async {
    repo.dispose();
    await env.dispose();
  });

  group('cache keys are captured when the request STARTS', () {
    test('a response requested under shop A is never stored under shop B',
        () async {
      await AppCacheManager.setShopScope(<String>['shopA']);

      final LayoutHandle<dynamic> handle = repo.revalidateSections(retailA);
      await settle();
      expect(env.adapter.pending, hasLength(1));

      // The customer moves to another shop while the request is in flight.
      await AppCacheManager.setShopScope(<String>['shopB']);

      env.adapter.pending.single.respondJson(
        sectionsPayload(
          storeKey: 'zepto',
          tabKey: 'chicken',
          title: 'Shop A chicken',
        ),
        headers: <String, List<String>>{
          'etag': <String>['"a1"'],
        },
      );
      final LayoutFetchResult<dynamic> result = await handle.result;
      expect(result.status, LayoutFetchStatus.updated);

      const SectionKey asShopB = SectionKey(
        storeKey: 'zepto',
        shopScope: 'shopB',
        priceMode: 'retail',
        tabKey: 'chicken',
      );
      expect(repo.peekSections(asShopB), isNull,
          reason: 'shop A response must not be readable as shop B');
      expect(repo.peekSections(retailA), isNotNull);
      expect(
        HiveService.sectionManifestBox
            .containsKey(LayoutDiskStore.sectionKeyOf(asShopB)),
        isFalse,
      );
      expect(
        HiveService.sectionManifestBox
            .containsKey(LayoutDiskStore.sectionKeyOf(retailA)),
        isTrue,
      );
    });

    test('a retail response is never stored as wholesale after a B2B switch',
        () async {
      final LayoutHandle<dynamic> handle = repo.revalidateSections(retailA);
      await settle();
      final FakeRequest request = env.adapter.pending.single;
      expect(request.query['priceMode'], 'retail',
          reason: 'price mode is sent explicitly, not left to the interceptor');

      await env.setPriceModeSetting('wholesale');
      request.respondJson(
        sectionsPayload(
          storeKey: 'zepto',
          tabKey: 'chicken',
          title: 'Retail',
        ),
      );
      await handle.result;

      const SectionKey wholesale = SectionKey(
        storeKey: 'zepto',
        shopScope: 'shopA',
        priceMode: 'wholesale',
        tabKey: 'chicken',
      );
      expect(repo.peekSections(wholesale), isNull);
      expect(repo.peekSections(retailA), isNotNull);
    });
  });

  group('in-flight sharing and cancellation', () {
    test('identical requests share one network call', () async {
      final LayoutHandle<dynamic> a = repo.revalidateSections(retailA);
      final LayoutHandle<dynamic> b = repo.revalidateSections(retailA);
      await settle();
      expect(env.adapter.requests, hasLength(1));

      env.adapter.pending.single.respondJson(
        sectionsPayload(storeKey: 'zepto', tabKey: 'chicken', title: 'X'),
      );
      expect((await a.result).status, LayoutFetchStatus.updated);
      expect((await b.result).snapshot, isNotNull);
    });

    test('a shared request is aborted only when its LAST claimant cancels',
        () async {
      final LayoutHandle<dynamic> a = repo.revalidateSections(retailA);
      final LayoutHandle<dynamic> b = repo.revalidateSections(retailA);
      await settle();
      final FakeRequest request = env.adapter.requests.single;

      a.cancel();
      await settle();
      expect(request.cancelled, isFalse, reason: 'b still needs it');

      b.cancel();
      await settle();
      expect(request.cancelled, isTrue);
      expect((await b.result).status, LayoutFetchStatus.cancelled);
    });

    test('a new request after a cancelled one starts a fresh network call',
        () async {
      final LayoutHandle<dynamic> first = repo.revalidateSections(retailA);
      await settle();
      first.cancel();
      final LayoutHandle<dynamic> second = repo.revalidateSections(retailA);
      await settle();
      expect(env.adapter.requests, hasLength(2));
      env.adapter.requests.last.respondJson(
        sectionsPayload(storeKey: 'zepto', tabKey: 'chicken', title: 'Fresh'),
      );
      expect((await second.result).status, LayoutFetchStatus.updated);
    });
  });

  group('revalidation', () {
    Future<void> seed() async {
      final LayoutHandle<dynamic> h = repo.revalidateSections(retailA);
      await settle();
      env.adapter.pending.single.respondJson(
        sectionsPayload(storeKey: 'zepto', tabKey: 'chicken', title: 'One'),
        headers: <String, List<String>>{
          'etag': <String>['"v1"'],
        },
      );
      await h.result;
    }

    test('sends If-None-Match and treats 304 as "nothing changed"', () async {
      await seed();
      int changes = 0;
      repo.changes.listen((_) => changes++);

      final LayoutHandle<dynamic> h = repo.revalidateSections(retailA);
      await settle();
      final FakeRequest request = env.adapter.pending.single;
      expect(request.ifNoneMatch, '"v1"');
      request.respondNotModified();
      final LayoutFetchResult<dynamic> result = await h.result;

      expect(result.status, LayoutFetchStatus.notModified);
      expect(changes, 0, reason: 'no change event => no rebuild');
    });

    test('identical bytes without an ETag produce no change event', () async {
      await seed();
      int changes = 0;
      repo.changes.listen((_) => changes++);

      final LayoutHandle<dynamic> h = repo.revalidateSections(retailA);
      await settle();
      env.adapter.pending.single.respondJson(
        sectionsPayload(storeKey: 'zepto', tabKey: 'chicken', title: 'One'),
      );
      final LayoutFetchResult<dynamic> result = await h.result;
      expect(result.status, LayoutFetchStatus.notModified);
      expect(changes, 0);
    });

    test('changed content emits exactly one change event', () async {
      await seed();
      int changes = 0;
      repo.changes.listen((_) => changes++);

      final LayoutHandle<dynamic> h = repo.revalidateSections(retailA);
      await settle();
      env.adapter.pending.single.respondJson(
        sectionsPayload(storeKey: 'zepto', tabKey: 'chicken', title: 'Two'),
      );
      await h.result;
      expect(changes, 1);
    });

    test('a failed fetch keeps the held snapshot and never blanks it',
        () async {
      await seed();
      final LayoutSnapshot<dynamic> before = repo.peekSections(retailA)!;

      final LayoutHandle<dynamic> h = repo.revalidateSections(retailA);
      await settle();
      env.adapter.pending.single.fail();
      final LayoutFetchResult<dynamic> result = await h.result;

      expect(result.status, LayoutFetchStatus.unavailable);
      expect(identical(repo.peekSections(retailA)!.data, before.data), isTrue);
    });

    test('a 5xx with nothing held reports unavailable, not an empty manifest',
        () async {
      final LayoutHandle<dynamic> h = repo.revalidateSections(retailA);
      await settle();
      env.adapter.pending.single.respondJson(<String, dynamic>{}, status: 503);
      final LayoutFetchResult<dynamic> result = await h.result;
      expect(result.status, LayoutFetchStatus.unavailable);
      expect(result.snapshot, isNull);
      expect(repo.peekSections(retailA), isNull);
    });

    test('deferCommit holds the result until commit()', () async {
      final LayoutHandle<dynamic> h =
          repo.revalidateSections(retailA, deferCommit: true);
      await settle();
      env.adapter.pending.single.respondJson(
        sectionsPayload(storeKey: 'zepto', tabKey: 'chicken', title: 'Held'),
      );
      final LayoutFetchResult<dynamic> result = await h.result;
      expect(repo.peekSections(retailA), isNull);
      result.commit();
      expect(repo.peekSections(retailA), isNotNull);
      result.commit(); // idempotent
    });
  });

  group('persistence', () {
    test('content restored from disk is served instantly but treated as stale',
        () async {
      final LayoutHandle<dynamic> h = repo.revalidateSections(retailA);
      await settle();
      env.adapter.pending.single.respondJson(
        sectionsPayload(storeKey: 'zepto', tabKey: 'chicken', title: 'Saved'),
      );
      await h.result;
      // The disk write is fire-and-forget; wait for it like a real relaunch would.
      await waitUntil(
        () => HiveService.sectionManifestBox
            .containsKey(LayoutDiskStore.sectionKeyOf(retailA)),
      );

      // New process: fresh repository, same Hive.
      final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'))
        ..httpClientAdapter = env.adapter;
      final StorefrontLayoutRepository restored =
          StorefrontLayoutRepository(dio: dio);
      addTearDown(restored.dispose);

      final LayoutSnapshot<dynamic>? snapshot = restored.peekSections(retailA);
      expect(snapshot, isNotNull);
      expect(restored.isFresh(snapshot!), isFalse);
    });

    test('markStale keeps content visible but forces revalidation', () async {
      final LayoutHandle<dynamic> h = repo.revalidateSections(retailA);
      await settle();
      env.adapter.pending.single.respondJson(
        sectionsPayload(storeKey: 'zepto', tabKey: 'chicken', title: 'T'),
      );
      await h.result;
      expect(repo.isFresh(repo.peekSections(retailA)!), isTrue);

      repo.markStale(storeKey: 'zepto', tabKey: 'chicken');
      expect(repo.peekSections(retailA), isNotNull);
      expect(repo.isFresh(repo.peekSections(retailA)!), isFalse);

      repo.markStale(storeKey: 'other');
      expect(repo.peekSections(retailA), isNotNull);
    });

    test('scopes beyond the retained few are pruned from disk', () async {
      for (int i = 0; i < 6; i++) {
        final SectionKey key = SectionKey(
          storeKey: 'zepto',
          shopScope: 'shop$i',
          priceMode: 'retail',
          tabKey: 'all',
        );
        await HiveService.sectionManifestBox
            .put(LayoutDiskStore.sectionKeyOf(key), 'v3\n0\n\n{}');
        await AppCacheManager.setShopScope(<String>['shop$i']);
      }
      final List<String> kept = HiveService.sectionManifestBox.keys
          .cast<String>()
          .map((String k) => AppCacheManager.scopeOfKey(k)!)
          .toList();
      expect(kept.toSet(), <String>{'shop2', 'shop3', 'shop4', 'shop5'});
    });
  });
}
