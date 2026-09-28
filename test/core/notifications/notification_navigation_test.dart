import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/core/notifications/notification_navigation.dart';

void main() {
  group('isShellDeepLinkPath', () {
    // Every path a shell-branch back-press can already recover from via
    // AppShell's own PopScope (app_bottom_nav.dart) — see its
    // `navigationShell.goBranch(0)` fallback.
    for (final path in <String>[
      '/home',
      '/off_zone',
      '/super_mall',
      '/cafe',
      '/orders',
      '/orders/abc-123',
      '/orders/abc-123/track',
      '/categories',
      '/categories/browse',
      '/categories/abc-123/products',
      '/categories?tab=price_drop',
      '/profile',
      '/profile/wallet',
      '/profile/wallet/send',
      '/profile/wishlist',
      '/profile/notifications',
      '/profile/notifications/preferences',
      '/profile/reviews',
      '/profile/settings',
    ]) {
      test('$path is a shell path', () {
        expect(isShellDeepLinkPath(path), isTrue);
      });
    }

    // Standalone routes with no shell/bottom-nav wrapping — .go() alone
    // leaves nothing beneath them, so they must NOT be classified as shell
    // paths (the caller then goes via Home first).
    for (final path in <String>[
      '/cart',
      '/cart/checkout',
      '/cart/checkout/payment',
      '/product/abc-123',
      '/products/some-slug',
      '/search',
      '/location-unavailable',
      '/scan-order-qr',
      '/scan-order-qr/abc-123',
      // Pinned to the root navigator despite living under /profile in the
      // route tree (see app_router.dart's own comments on each).
      '/profile/edit',
      '/profile/wallet/topup',
      '/profile/addresses',
      '/profile/addresses/add',
    ]) {
      test('$path is NOT a shell path', () {
        expect(isShellDeepLinkPath(path), isFalse);
      });
    }

    // The one real collision a naive "starts with /orders/" check would
    // get wrong — a top-level sibling route, not a child of the Orders
    // branch.
    test('/orders/success/:id is NOT a shell path (collides with /orders/)', () {
      expect(isShellDeepLinkPath('/orders/success/abc-123'), isFalse);
    });
  });

  group('navigateToNotificationTarget', () {
    test('a shell path calls go() only, never push()', () {
      final calls = <String>[];
      navigateToNotificationTarget(
        '/orders',
        go: (p) => calls.add('go:$p'),
        push: (p) => calls.add('push:$p'),
      );
      expect(calls, <String>['go:/orders']);
    });

    test('a standalone path goes Home first, then pushes the real target', () {
      final calls = <String>[];
      navigateToNotificationTarget(
        '/cart',
        go: (p) => calls.add('go:$p'),
        push: (p) => calls.add('push:$p'),
      );
      expect(calls, <String>['go:/home', 'push:/cart']);
    });

    test('a standalone nested path (checkout) also goes Home first', () {
      final calls = <String>[];
      navigateToNotificationTarget(
        '/cart/checkout',
        go: (p) => calls.add('go:$p'),
        push: (p) => calls.add('push:$p'),
      );
      expect(calls, <String>['go:/home', 'push:/cart/checkout']);
    });

    test('the order-success collision case also goes Home first', () {
      final calls = <String>[];
      navigateToNotificationTarget(
        '/orders/success/abc-123',
        go: (p) => calls.add('go:$p'),
        push: (p) => calls.add('push:$p'),
      );
      expect(calls, <String>['go:/home', 'push:/orders/success/abc-123']);
    });
  });
}
