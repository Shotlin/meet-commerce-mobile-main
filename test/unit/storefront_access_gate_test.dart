// Regression test for a reported bug: an already-logged-in account with a
// saved address occasionally saw the "Enable Location" bottom sheet anyway,
// gone as soon as it was dismissed. Root cause was a race in AppShell
// (app_bottom_nav.dart): while storefrontAccessProvider — a signed-in
// account's GET /addresses lookup — was still in flight, AppShell fell back
// to GuestLocationGate, a widget that independently fires the guest
// location-prompt sheet off a fast, LOCAL-ONLY cache unrelated to whether
// the account already has an address. isStorefrontAccessStillResolving is
// the extracted predicate that closes that gap: it must be true only for
// the genuine "we have never heard back yet" state, never for a resolved
// value (even `false`) or a background refresh of an already-known value.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/shared/widgets/app_bottom_nav.dart';

void main() {
  group('isStorefrontAccessStillResolving', () {
    test('true on the very first frame, before anything has resolved', () {
      expect(
        isStorefrontAccessStillResolving(const AsyncLoading<bool>()),
        isTrue,
      );
    });

    test('false once resolved true (account has a saved address)', () {
      expect(
        isStorefrontAccessStillResolving(const AsyncData<bool>(true)),
        isFalse,
      );
    });

    test('false once resolved false (account genuinely has none)', () {
      expect(
        isStorefrontAccessStillResolving(const AsyncData<bool>(false)),
        isFalse,
      );
    });

    test('false on an error — must not be treated as "still loading"', () {
      expect(
        isStorefrontAccessStillResolving(
          AsyncError<bool>(Exception('network'), StackTrace.empty),
        ),
        isFalse,
      );
    });
  });

  group('AppShell storefront gating, end to end via a real ProviderContainer',
      () {
    // Exercises the actual scenario the bug report described, through
    // Riverpod's own public refresh mechanism rather than any internal API:
    // once storefrontAccessProvider has genuinely resolved for an
    // already-addressed account, invalidating and re-awaiting it (exactly
    // what happens whenever addressProvider is invalidated elsewhere in the
    // app) must keep isStorefrontAccessStillResolving false throughout the
    // refresh — a later background refetch must never flash the loading
    // skeleton (let alone GuestLocationGate) for an account already known
    // to have an address.
    test('stays settled across a refresh of an already-resolved value',
        () async {
      var callCount = 0;
      final provider = FutureProvider<bool>((ref) async {
        callCount++;
        return true;
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(provider.future);
      expect(
        isStorefrontAccessStillResolving(container.read(provider)),
        isFalse,
      );

      container.invalidate(provider);
      // Immediately after invalidation but before the new future settles,
      // Riverpod reports isLoading == true while still exposing the
      // previous value — the exact "isRefreshing" state this predicate must
      // not treat as "still resolving".
      expect(
        isStorefrontAccessStillResolving(container.read(provider)),
        isFalse,
      );

      await container.read(provider.future);
      expect(callCount, 2);
      expect(
        isStorefrontAccessStillResolving(container.read(provider)),
        isFalse,
      );
    });
  });
}
