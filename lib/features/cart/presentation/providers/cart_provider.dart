import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/analytics/analytics_service.dart';
import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/features/cart/data/datasources/cart_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/cart/data/repositories/cart_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/usecases/add_to_cart.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/usecases/clear_cart.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/usecases/get_cart.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/usecases/remove_item.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/usecases/update_item.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/usecases/validate_cart.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';

part 'cart_provider.g.dart';

/// Surfaces cart-mutation failures (add/update/remove) that happen after
/// the widget that triggered them (e.g. a product card's +/- button) has
/// already been unmounted — navigated away from, or the screen popped —
/// so the normal `if (!context.mounted) return;` snackbar guard in the
/// calling widget silently swallows the error. `CartNotifier` is
/// `keepAlive` and outlives any single screen, so it publishes failures
/// here; [AppShell] (the always-mounted root shell) listens and shows
/// the toast regardless of which screen was on top when the request
/// actually completed. Without this, a quantity change that fails after
/// the user has already navigated away looks to them like it silently
/// "reset itself" on next launch — the optimistic UI reverted correctly,
/// but nothing ever told them why.
class CartMutationFailureNotifier extends ValueNotifier<Failure?> {
  CartMutationFailureNotifier() : super(null);

  void report(Failure failure) {
    value = failure;
  }
}

final cartMutationFailureNotifier = CartMutationFailureNotifier();

final cartRemoteDataSourceProvider = Provider<CartRemoteDataSource>((Ref ref) {
  return CartRemoteDataSource(ref.watch(apiClientProvider));
});

final cartRepositoryProvider = Provider<CartRepository>((Ref ref) {
  return CartRepositoryImpl(
    remoteDataSource: ref.watch(cartRemoteDataSourceProvider),
  );
});

final getCartUseCaseProvider = Provider<GetCartUseCase>((Ref ref) {
  return GetCartUseCase(ref.watch(cartRepositoryProvider));
});

final addToCartUseCaseProvider = Provider<AddToCartUseCase>((Ref ref) {
  return AddToCartUseCase(ref.watch(cartRepositoryProvider));
});

final updateCartItemUseCaseProvider = Provider<UpdateItemUseCase>((Ref ref) {
  return UpdateItemUseCase(ref.watch(cartRepositoryProvider));
});

final removeCartItemUseCaseProvider = Provider<RemoveItemUseCase>((Ref ref) {
  return RemoveItemUseCase(ref.watch(cartRepositoryProvider));
});

final clearCartUseCaseProvider = Provider<ClearCartUseCase>((Ref ref) {
  return ClearCartUseCase(ref.watch(cartRepositoryProvider));
});

final validateCartUseCaseProvider = Provider<ValidateCartUseCase>((Ref ref) {
  return ValidateCartUseCase(ref.watch(cartRepositoryProvider));
});

class CartActionResult {
  const CartActionResult({
    this.failure,
  });

  final Failure? failure;

  bool get isSuccess => failure == null;
}

class CartValidationOutcome {
  const CartValidationOutcome({
    required this.valid,
    required this.warnings,
    this.failure,
  });

  final bool valid;
  final List<String> warnings;
  final Failure? failure;

  bool get hasFailure => failure != null;
}

@Riverpod(keepAlive: true)
class CartNotifier extends _$CartNotifier {
  @override
  Future<CartEntity> build() async {
    final isAuthenticated = ref.watch(authStateProvider) is AuthAuthenticated;
    if (!isAuthenticated) {
      return CartEntity.empty();
    }

    final result = await ref.read(getCartUseCaseProvider).call();
    return result.fold(
      (failure) => throw StateError(failure.message),
      (cart) => cart,
    );
  }

  Future<CartActionResult> addItem(
    String productId,
    int quantity, {
    ProductEntity? product,
    String? shopProductId,
  }) async {
    if (!_isAuthenticated) {
      return const CartActionResult(
        failure: AuthFailure(message: 'Please log in to add items to cart.'),
      );
    }

    final sanitizedQuantity = quantity.clamp(1, 50).toInt();
    final previous = _currentCart;
    state = AsyncData(
      _optimisticAdd(
        previous,
        productId: productId,
        quantity: sanitizedQuantity,
        product: product,
      ),
    );

    final result = await ref.read(addToCartUseCaseProvider).call(
          productId: productId,
          quantity: sanitizedQuantity,
          shopProductId: shopProductId,
        );

    return result.fold(
      (failure) {
        state = AsyncData(previous);
        return CartActionResult(failure: failure);
      },
      (cart) {
        state = AsyncData(cart);
        final price = _priceForProduct(
          cart,
          productId,
          fallback: product?.effectivePrice ?? 0,
        );
        unawaited(
          ref.read(analyticsServiceProvider).logAddToCart(
                productId,
                sanitizedQuantity,
                price,
              ),
        );
        return const CartActionResult();
      },
    );
  }

  Future<CartActionResult> updateItem(
    String productId,
    int quantity, {
    String? shopProductId,
  }) async {
    if (!_isAuthenticated) {
      return const CartActionResult(
        failure: AuthFailure(message: 'Please log in to update your cart.'),
      );
    }

    final sanitizedQuantity = quantity.clamp(1, 50).toInt();
    final previous = _currentCart;
    state = AsyncData(
      _optimisticUpdate(
        previous,
        productId: productId,
        quantity: sanitizedQuantity,
      ),
    );

    final result = await ref.read(updateCartItemUseCaseProvider).call(
          productId: productId,
          quantity: sanitizedQuantity,
          shopProductId: shopProductId,
        );

    return result.fold(
      (failure) {
        // If item is no longer in the backend cart (e.g. stale after
        // validateCart stripped it), refresh from backend so the UI
        // re-syncs rather than staying in a broken optimistic state.
        if (failure is NotFoundFailure ||
            failure.message.contains('not in cart') ||
            failure.message.contains('CART_ITEM_NOT_FOUND')) {
          ref.invalidateSelf();
          const notFound = NotFoundFailure(
            message: 'Item no longer in cart. Cart has been refreshed.',
          );
          cartMutationFailureNotifier.report(notFound);
          return const CartActionResult(failure: notFound);
        }
        state = AsyncData(previous);
        cartMutationFailureNotifier.report(failure);
        return CartActionResult(failure: failure);
      },
      (cart) {
        state = AsyncData(cart);
        return const CartActionResult();
      },
    );
  }

  Future<CartActionResult> removeItem(
    String productId, {
    String? shopProductId,
  }) async {
    if (!_isAuthenticated) {
      return const CartActionResult(
        failure: AuthFailure(message: 'Please log in to update your cart.'),
      );
    }

    final previous = _currentCart;
    state = AsyncData(
      _rebuildCart(
        previous.items
            .where((item) => item.productId != productId)
            .toList(growable: false),
      ),
    );

    final result = await ref
        .read(removeCartItemUseCaseProvider)
        .call(productId, shopProductId: shopProductId);

    return result.fold(
      (failure) {
        // If item is not found on backend, keep the optimistic removal
        // (it's already gone from UI) and refresh cart to fully sync.
        if (failure is NotFoundFailure ||
            failure.message.contains('not in cart') ||
            failure.message.contains('CART_ITEM_NOT_FOUND')) {
          ref.invalidateSelf();
          return const CartActionResult(); // treat as success — item is gone
        }
        state = AsyncData(previous);
        cartMutationFailureNotifier.report(failure);
        return CartActionResult(failure: failure);
      },
      (cart) {
        state = AsyncData(cart);
        return const CartActionResult();
      },
    );
  }

  Future<CartActionResult> clearCart() async {
    if (!_isAuthenticated) {
      return const CartActionResult(
        failure: AuthFailure(message: 'Please log in to update your cart.'),
      );
    }

    final previous = _currentCart;
    state = AsyncData(CartEntity.empty());

    final result = await ref.read(clearCartUseCaseProvider).call();
    return result.fold(
      (failure) {
        state = AsyncData(previous);
        return CartActionResult(failure: failure);
      },
      (_) {
        state = AsyncData(CartEntity.empty());
        return const CartActionResult();
      },
    );
  }

  Future<CartValidationOutcome> validateAndProceed() async {
    if (!_isAuthenticated) {
      return const CartValidationOutcome(
        valid: false,
        warnings: <String>[],
        failure: AuthFailure(message: 'Please log in to continue.'),
      );
    }

    final result = await ref.read(validateCartUseCaseProvider).call();
    return result.fold(
      (failure) => CartValidationOutcome(
        valid: false,
        warnings: const <String>[],
        failure: failure,
      ),
      (validation) {
        state = AsyncData(validation.cart);
        return CartValidationOutcome(
          valid: validation.valid,
          warnings: validation.warnings,
        );
      },
    );
  }

  void refresh() {
    ref.invalidateSelf();
  }

  bool get _isAuthenticated => ref.read(authStateProvider) is AuthAuthenticated;

  CartEntity get _currentCart => switch (state) {
        AsyncData(:final value) => value,
        _ => CartEntity.empty(),
      };

  CartEntity _optimisticAdd(
    CartEntity cart, {
    required String productId,
    required int quantity,
    ProductEntity? product,
  }) {
    final items = cart.items.toList(growable: true);
    final index = items.indexWhere((item) => item.productId == productId);

    if (index >= 0) {
      final existing = items[index];
      final nextQuantity = (existing.quantity + quantity).clamp(1, 50);
      items[index] = existing.copyWith(
        quantity: nextQuantity,
        total: existing.effectivePrice * nextQuantity,
      );
      return _rebuildCart(items);
    }

    final optimisticItem = CartItemEntity(
      productId: productId,
      name: product?.name ?? 'Updating item...',
      price: product?.price ?? 0,
      salePrice: product?.salePrice,
      quantity: quantity.clamp(1, 50),
      total: (product?.effectivePrice ?? 0) * quantity.clamp(1, 50),
      unit: product?.unit,
      netQuantity: product?.netQuantity,
      optionLabel: product?.optionLabel,
      thumbnailUrl: product?.thumbnailUrl ??
          (product?.images.isNotEmpty == true ? product!.images.first : null),
    );
    items.add(optimisticItem);
    return _rebuildCart(items);
  }

  CartEntity _optimisticUpdate(
    CartEntity cart, {
    required String productId,
    required int quantity,
  }) {
    final items = cart.items.map((item) {
      if (item.productId != productId) {
        return item;
      }
      return item.copyWith(
        quantity: quantity,
        total: item.effectivePrice * quantity,
      );
    }).toList(growable: false);

    return _rebuildCart(items);
  }

  CartEntity _rebuildCart(List<CartItemEntity> items) {
    final subtotal = items.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );
    final itemCount = items.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );

    return CartEntity(
      items: items,
      subtotal: subtotal,
      itemCount: itemCount,
    );
  }

  double _priceForProduct(
    CartEntity cart,
    String productId, {
    required double fallback,
  }) {
    for (final item in cart.items) {
      if (item.productId == productId) {
        return item.effectivePrice;
      }
    }
    return fallback;
  }
}

@riverpod
int cartCount(Ref ref) {
  final cartAsync = ref.watch(cartProvider);
  return switch (cartAsync) {
    AsyncData(:final value) => value.itemCount,
    _ => 0,
  };
}

final _cartItemQuantitiesProvider = Provider<Map<String, int>>((Ref ref) {
  return ref.watch(
    cartProvider.select((cartAsync) {
      final cart = switch (cartAsync) {
        AsyncData(:final value) => value,
        _ => null,
      };

      if (cart == null || cart.items.isEmpty) {
        return const <String, int>{};
      }

      return Map<String, int>.unmodifiable(
        <String, int>{
          for (final item in cart.items) item.productId: item.quantity,
        },
      );
    }),
  );
});

@riverpod
int cartItemQuantity(Ref ref, String productId) {
  return ref.watch(
    _cartItemQuantitiesProvider
        .select((quantities) => quantities[productId] ?? 0),
  );
}

/// Derived provider: cart subtotal as a plain double (0.0 when cart is loading/empty).
/// Used by DeliveryPromoBar to compute remaining amount for free delivery.
final cartTotalProvider = Provider<double>((Ref ref) {
  final cartAsync = ref.watch(cartProvider);
  return cartAsync.asData?.value.subtotal ?? 0.0;
});

void showCartSnackBar(
  BuildContext context,
  String message, {
  bool isError = true, // kept for API compatibility, type now auto-detected
}) {
  final displayMessage = _mapCartErrorMessage(message);
  AppToast.show(context, displayMessage);
}

/// Maps technical backend error messages to user-friendly copy.
/// Prevents raw strings like "Invalid or expired refresh token" reaching users.
String _mapCartErrorMessage(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('refresh token') ||
      lower.contains('expired') && lower.contains('token') ||
      lower.contains('invalid token') ||
      lower.contains('unauthorized') ||
      lower.contains('not authenticated') ||
      lower.contains('session has expired')) {
    return 'Your session has expired. Please sign in again.';
  }
  if (lower.contains('jwt') || lower.contains('signature')) {
    return 'Your session has expired. Please sign in again.';
  }
  if (lower.contains('uuid') || lower.contains('syntax error')) {
    return 'Something went wrong. Please try again.';
  }
  if (lower.contains('validation error') && lower.length < 20) {
    return 'Something went wrong. Please try again.';
  }
  // FIX: Real users with no allocation get a clear action message.
  if (lower.contains('shop_allocation_required') ||
      lower.contains('please set your delivery address') ||
      lower.contains('allocation_required')) {
    return 'Please set your delivery address to add items to cart.';
  }
  if (lower.contains('not available in any of your shops') ||
      lower.contains('not available in your delivery area')) {
    return 'This product is not available at your location.';
  }
  return raw;
}
