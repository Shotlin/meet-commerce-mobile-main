import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/wishlist/presentation/providers/wishlist_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/widgets/login_required_sheet.dart';

enum PendingAuthIntentType {
  route,
  addToCart,
  toggleWishlist,
}

class PendingAuthIntent {
  const PendingAuthIntent._({
    required this.type,
    this.route,
    this.product,
    this.quantity = 1,
    this.originPath,
  });

  const PendingAuthIntent.route(
    String route, {
    String? originPath,
  }) : this._(
          type: PendingAuthIntentType.route,
          route: route,
          originPath: originPath,
        );

  const PendingAuthIntent.addToCart(
    ProductEntity product, {
    int quantity = 1,
    String? originPath,
  }) : this._(
          type: PendingAuthIntentType.addToCart,
          product: product,
          quantity: quantity,
          originPath: originPath,
        );

  const PendingAuthIntent.toggleWishlist(
    ProductEntity product, {
    String? originPath,
  }) : this._(
          type: PendingAuthIntentType.toggleWishlist,
          product: product,
          originPath: originPath,
        );

  final PendingAuthIntentType type;
  final String? route;
  final ProductEntity? product;
  final int quantity;
  final String? originPath;

  String get targetPath => switch (type) {
        PendingAuthIntentType.route => route ?? RouteNames.home,
        _ => originPath ?? RouteNames.home,
      };
}

class PendingAuthIntentNotifier extends Notifier<PendingAuthIntent?> {
  @override
  PendingAuthIntent? build() => null;

  void remember(PendingAuthIntent intent) {
    state = intent;
  }

  PendingAuthIntent? take() {
    final current = state;
    state = null;
    return current;
  }
}

final pendingAuthIntentProvider =
    NotifierProvider<PendingAuthIntentNotifier, PendingAuthIntent?>(
  PendingAuthIntentNotifier.new,
);

final authGateControllerProvider = Provider<AuthGateController>((ref) {
  return AuthGateController(ref);
});

class AuthGateController {
  const AuthGateController(this._ref);

  final Ref _ref;

  bool get isAuthenticated => _ref.read(authStateProvider) is AuthAuthenticated;

  Future<bool> protectRoute(
    BuildContext context, {
    required String route,
    required String title,
    required String message,
  }) {
    return _requireLogin(
      context,
      intent: PendingAuthIntent.route(
        route,
        originPath: GoRouterState.of(context).uri.path,
      ),
      title: title,
      message: message,
    );
  }

  Future<bool> protectAddToCart(
    BuildContext context,
    ProductEntity product, {
    int quantity = 1,
  }) {
    return _requireLogin(
      context,
      intent: PendingAuthIntent.addToCart(
        product,
        quantity: quantity,
        originPath: GoRouterState.of(context).uri.path,
      ),
      title: 'Log in to add items',
      message:
          'Please log in first to add this product to your cart and continue shopping.',
    );
  }

  Future<bool> protectWishlist(
    BuildContext context,
    ProductEntity product,
  ) {
    return _requireLogin(
      context,
      intent: PendingAuthIntent.toggleWishlist(
        product,
        originPath: GoRouterState.of(context).uri.path,
      ),
      title: 'Log in to save favourites',
      message:
          'Please log in first to save products and access them from your wishlist anytime.',
    );
  }

  void rememberRouteIntent(String route) {
    final current = _ref.read(pendingAuthIntentProvider);
    if (current?.type == PendingAuthIntentType.route &&
        current?.route == route) {
      return;
    }
    _ref
        .read(pendingAuthIntentProvider.notifier)
        .remember(PendingAuthIntent.route(route));
  }

  Future<void> consumeAndResume(BuildContext context) async {
    final intent = _ref.read(pendingAuthIntentProvider.notifier).take();

    if (intent == null) {
      if (context.mounted) {
        context.go(RouteNames.home);
      }
      return;
    }

    if (context.mounted) {
      context.go(intent.targetPath);
    }

    await Future<void>.delayed(const Duration(milliseconds: 120));

    switch (intent.type) {
      case PendingAuthIntentType.route:
        return;
      case PendingAuthIntentType.addToCart:
        final product = intent.product;
        if (product == null) {
          return;
        }
        final result = await _ref.read(cartProvider.notifier).addItem(
              product.id,
              intent.quantity,
              product: product,
            );
        if (!result.isSuccess && context.mounted) {
          _showMessage(context, result.failure?.message);
        }
      case PendingAuthIntentType.toggleWishlist:
        final product = intent.product;
        if (product == null) {
          return;
        }
        final result =
            await _ref.read(wishlistProvider.notifier).toggleWishlist(product);
        if (!result.isSuccess && context.mounted) {
          _showMessage(context, result.failure?.message);
        }
    }
  }

  Future<bool> _requireLogin(
    BuildContext context, {
    required PendingAuthIntent intent,
    required String title,
    required String message,
  }) async {
    if (isAuthenticated) {
      return true;
    }

    // Capture router before the async gap (sheet open) to avoid stale context
    final router = GoRouter.of(context);

    final shouldLogin = await LoginRequiredSheet.show(
      context,
      title: title,
      message: message,
    );

    if (!shouldLogin) {
      return false;
    }

    _ref.read(pendingAuthIntentProvider.notifier).remember(intent);
    router.push(RouteNames.phone);
    return false;
  }

  void _showMessage(BuildContext context, String? message) {
    if (message == null || message.trim().isEmpty || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }
}
