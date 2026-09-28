import 'package:bakaloo_flutter_app/routing/route_names.dart';

/// Paths whose target screen lives *inside* the bottom-nav shell
/// (`StatefulShellRoute.indexedStack` in app_router.dart — the Home/Orders/
/// Categories/Profile branches). For these, `AppShell`'s own `PopScope`
/// (lib/shared/widgets/app_bottom_nav.dart) already returns the user to the
/// Home branch once there's nothing left to pop within the current branch —
/// so a plain `router.go(path)` is correct and sufficient.
///
/// Everything else — `/cart`, `/product/:id`, `/search`,
/// `/orders/success/:id`, `/scan-order-qr`, and the three profile routes
/// explicitly pinned to the root navigator (`edit`, `wallet/topup`,
/// `addresses`) — renders with NO shell wrapping at all. A bare
/// `router.go(path)` to one of these replaces the ENTIRE navigation stack
/// with just that one route (go_router's `.go()` always computes a fresh
/// match list from the target alone, discarding whatever was there before),
/// so the very first back-press/swipe finds nothing to pop and exits the
/// app — reproduced by tracing app_router.dart's actual route declarations,
/// not assumed.
///
/// `/orders/success/:orderId` is the one genuine collision with a simple
/// "starts with /orders/" check — it's declared as a top-level sibling
/// route, not a child of the Orders branch — so it's excluded explicitly.
bool isShellDeepLinkPath(String path) {
  final base = path.split('?').first;

  if (base == RouteNames.home || base.startsWith('${RouteNames.home}/')) {
    return true;
  }
  if (base == RouteNames.offZone ||
      base == RouteNames.superMall ||
      base == RouteNames.cafe) {
    return true;
  }
  if (base == RouteNames.orders ||
      (base.startsWith('${RouteNames.orders}/') &&
          !base.startsWith('${RouteNames.orders}/success'))) {
    return true;
  }
  if (base == RouteNames.categories ||
      base.startsWith('${RouteNames.categories}/')) {
    return true;
  }
  if (base == RouteNames.profile || base.startsWith('${RouteNames.profile}/')) {
    const rootPinned = <String>[
      '/profile/edit',
      RouteNames.topup,
      RouteNames.addresses,
    ];
    final isRootPinned = rootPinned.any(
      (p) => base == p || base.startsWith('$p/'),
    );
    return !isRootPinned;
  }
  return false;
}

/// Navigates to a notification's resolved deep-link `path` so the back
/// button/gesture always has somewhere real inside the app to land, instead
/// of exiting outright — the fix for the "tap a Cart/Search/etc. push from a
/// killed app, back-press closes the app" bug. `go`/`push` are the router's
/// own methods, passed in so this stays a pure function with no GoRouter/
/// BuildContext dependency (both real call sites — `fcm_service.dart`'s
/// notification-tap handler and the in-app live-notification banner in
/// `app_bottom_nav.dart` — share this one implementation).
void navigateToNotificationTarget(
  String path, {
  required void Function(String) go,
  required void Function(String) push,
}) {
  if (isShellDeepLinkPath(path)) {
    go(path);
    return;
  }
  // Standalone route with no shell wrapping — land on Home first so it's
  // sitting underneath, then push the real target on top of it.
  go(RouteNames.home);
  push(path);
}
