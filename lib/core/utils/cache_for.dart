import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps an `autoDispose` provider's already-fetched value alive for
/// [duration] after its last listener unsubscribes, instead of disposing
/// (and losing the fetched data) the instant a screen is popped.
///
/// Call once at the top of the provider's build function:
/// ```dart
/// @riverpod
/// Future<Foo> foo(Ref ref) async {
///   ref.cacheFor(const Duration(minutes: 5));
///   return fetchFoo();
/// }
/// ```
///
/// Navigating away and back within [duration] re-subscribes before the
/// pending disposal timer fires, so the screen sees the cached value
/// instantly instead of a fresh loading spinner. If the provider is still
/// genuinely watched by anything else (e.g. a real dependency, not just a
/// screen that popped), the timer never starts in the first place. Once
/// [duration] elapses with zero listeners, the provider disposes normally —
/// this is a bounded cache, not `keepAlive: true` forever, so it can't grow
/// memory or serve indefinitely stale data.
extension CacheForRef on Ref {
  void cacheFor(Duration duration) {
    final link = keepAlive();
    Timer? timer;

    onDispose(() {
      timer?.cancel();
    });

    onCancel(() {
      timer?.cancel();
      timer = Timer(duration, link.close);
    });

    onResume(() {
      timer?.cancel();
    });
  }
}
