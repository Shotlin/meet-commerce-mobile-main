import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/core/utils/cache_for.dart';

void main() {
  test('value survives a listener dropping and re-subscribing within the '
      'cache window — no refetch', () {
    fakeAsync((async) {
      var fetchCount = 0;
      final provider = FutureProvider.autoDispose<int>((ref) async {
        ref.cacheFor(const Duration(minutes: 5));
        fetchCount++;
        return fetchCount;
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      var sub = container.listen(provider, (_, __) {});
      async.flushMicrotasks();
      expect(container.read(provider).value, 1);
      expect(fetchCount, 1);

      // Screen popped — last listener drops.
      sub.close();
      async.elapse(const Duration(minutes: 2));

      // Screen re-opened well within the 5-minute window.
      sub = container.listen(provider, (_, __) {});
      async.flushMicrotasks();
      expect(fetchCount, 1, reason: 'must not refetch — still cached');
      expect(container.read(provider).value, 1);

      sub.close();
    });
  });

  test('disposes and refetches once the cache window fully elapses with no '
      'listeners', () {
    fakeAsync((async) {
      var fetchCount = 0;
      final provider = FutureProvider.autoDispose<int>((ref) async {
        ref.cacheFor(const Duration(minutes: 5));
        fetchCount++;
        return fetchCount;
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      var sub = container.listen(provider, (_, __) {});
      async.flushMicrotasks();
      expect(fetchCount, 1);

      sub.close();
      // Past the 5-minute window with zero listeners the whole time.
      async.elapse(const Duration(minutes: 6));

      sub = container.listen(provider, (_, __) {});
      async.flushMicrotasks();
      expect(fetchCount, 2, reason: 'must have disposed and refetched');

      sub.close();
    });
  });

  test('a still-live dependent keeps the provider alive indefinitely — '
      'the timer never starts while genuinely watched', () {
    fakeAsync((async) {
      var fetchCount = 0;
      final provider = FutureProvider.autoDispose<int>((ref) async {
        ref.cacheFor(const Duration(seconds: 1));
        fetchCount++;
        return fetchCount;
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sub = container.listen(provider, (_, __) {});
      async.flushMicrotasks();
      expect(fetchCount, 1);

      // Far past the cache duration, but the listener never closed.
      async.elapse(const Duration(seconds: 10));
      expect(fetchCount, 1, reason: 'still watched — must not refetch');

      sub.close();
    });
  });
}
