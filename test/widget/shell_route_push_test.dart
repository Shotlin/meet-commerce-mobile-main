// Reproduces, in isolation, the exact go_router shape that caused the
// "Add Address to Proceed" blank-screen bug: a route mounted outside the
// StatefulShellRoute (like CartScreen) pushing into a route nested inside a
// shell branch (like /profile/addresses/add). Mirrors app_router.dart's
// structure without needing auth/Hive/riverpod setup, so it isolates the
// go_router mechanism itself.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _buildRouter({required bool withParentNavigatorKey}) {
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final branchNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'branch');

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/outside',
    routes: <RouteBase>[
      GoRoute(
        path: '/outside',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => context.push('/shell/a/add'),
              child: const Text('Add Address to Proceed'),
            ),
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => Scaffold(
          body: navigationShell,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: navigationShell.currentIndex,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/home',
                builder: (context, state) =>
                    const Scaffold(body: Text('Home')),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchNavigatorKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/shell/a',
                builder: (context, state) =>
                    const Scaffold(body: Text('Profile')),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'add',
                    parentNavigatorKey:
                        withParentNavigatorKey ? rootNavigatorKey : null,
                    builder: (context, state) =>
                        const Scaffold(body: Text('Add Address Form')),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

void main() {
  // Note: IndexedStack keeps every branch's widgets mounted, so
  // find.text('Add Address Form') alone can't tell "visible" from "buried in
  // an inactive branch slot" — that's exactly the bug's mechanism. The
  // reliable signal is whether the target page is still wrapped in the
  // shell's chrome (BottomNavigationBar): entangled with branch/IndexedStack
  // state (bug) vs. a clean top-level page on the root navigator (fix) —
  // which matches the user's report of the bottom nav reappearing with
  // "Profile" highlighted over blank content.
  testWidgets(
    'BUG: without parentNavigatorKey, pushing a nested shell-branch route '
    'from outside the shell leaves the target entangled in shell chrome',
    (tester) async {
      final router = _buildRouter(withParentNavigatorKey: false);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Add Address to Proceed'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
    },
  );

  testWidgets(
    'FIX: parentNavigatorKey pushes the target as a clean full-screen page '
    'on the root navigator, with no shell chrome',
    (tester) async {
      final router = _buildRouter(withParentNavigatorKey: true);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Add Address to Proceed'));
      await tester.pumpAndSettle();

      expect(find.text('Add Address Form'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
    },
  );
}
