import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';
import 'package:bakaloo_flutter_app/features/wishlist/data/datasources/wishlist_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/wishlist/data/repositories/wishlist_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/wishlist/domain/entities/wishlist_entity.dart';
import 'package:bakaloo_flutter_app/features/wishlist/domain/repositories/wishlist_repository.dart';
import 'package:bakaloo_flutter_app/features/wishlist/domain/usecases/get_wishlist.dart';
import 'package:bakaloo_flutter_app/features/wishlist/domain/usecases/move_to_cart.dart';
import 'package:bakaloo_flutter_app/features/wishlist/domain/usecases/toggle_wishlist.dart';

part 'wishlist_provider.g.dart';

class WishlistActionResult {
  const WishlistActionResult({
    this.failure,
    this.movedCount = 0,
  });

  final Failure? failure;
  final int movedCount;

  bool get isSuccess => failure == null;
}

final wishlistRemoteDataSourceProvider = Provider<WishlistRemoteDataSource>((
  Ref ref,
) {
  return WishlistRemoteDataSource(ref.watch(apiClientProvider));
});

final wishlistRepositoryProvider = Provider<WishlistRepository>((Ref ref) {
  return WishlistRepositoryImpl(
    remoteDataSource: ref.watch(wishlistRemoteDataSourceProvider),
  );
});

final getWishlistUseCaseProvider = Provider<GetWishlistUseCase>((Ref ref) {
  return GetWishlistUseCase(ref.watch(wishlistRepositoryProvider));
});

final toggleWishlistUseCaseProvider =
    Provider<ToggleWishlistUseCase>((Ref ref) {
  return ToggleWishlistUseCase(ref.watch(wishlistRepositoryProvider));
});

final moveWishlistToCartUseCaseProvider =
    Provider<MoveToCartUseCase>((Ref ref) {
  return MoveToCartUseCase(ref.watch(wishlistRepositoryProvider));
});

@Riverpod(keepAlive: true)
class WishlistNotifier extends _$WishlistNotifier {
  @override
  Future<WishlistEntity> build() async {
    final isAuthenticated = ref.watch(authStateProvider) is AuthAuthenticated;
    if (!isAuthenticated) {
      return const WishlistEntity();
    }

    final result = await ref.read(getWishlistUseCaseProvider).call();
    return result.fold(
      (failure) => throw StateError(failure.message),
      (wishlist) => wishlist,
    );
  }

  Future<WishlistActionResult> toggleWishlist(ProductEntity product) async {
    if (!_isAuthenticated) {
      return const WishlistActionResult(
        failure: AuthFailure(message: 'Please log in to save favourites.'),
      );
    }

    final previous = _currentWishlist;
    final isInWishlist = previous.items.any(
      (item) => item.productId == product.id,
    );

    final optimistic = isInWishlist
        ? previous.copyWith(
            items: previous.items
                .where((item) => item.productId != product.id)
                .toList(growable: false),
            total: (previous.total - 1).clamp(0, 999999),
          )
        : previous.copyWith(
            items: <WishlistItemEntity>[
              WishlistItemEntity(
                productId: product.id,
                product: product,
                addedAt: DateTime.now(),
              ),
              ...previous.items,
            ],
            total: previous.total + 1,
          );

    state = AsyncData(optimistic);

    final result = await ref.read(toggleWishlistUseCaseProvider).call(
          product.id,
          isInWishlist: isInWishlist,
        );

    return result.fold(
      (failure) {
        state = AsyncData(previous);
        return WishlistActionResult(failure: failure);
      },
      (wishlist) {
        state = AsyncData(wishlist);
        return const WishlistActionResult();
      },
    );
  }

  /// Adds a product to the wishlist by id alone — for callers (e.g. the
  /// "Save this for later?" cart-removal prompt) that only have a
  /// [CartItemEntity] on hand, not the full [ProductEntity] [toggleWishlist]
  /// needs for its optimistic-UI step. The API call itself only ever needed
  /// the id; this just skips fabricating a fake product to get there.
  /// Callers are expected to already know the product isn't wishlisted
  /// (e.g. via [wishlistIdsProvider]) — this always sends `isInWishlist:
  /// false` since it's an add-only entry point.
  Future<WishlistActionResult> addToWishlistById(String productId) async {
    if (!_isAuthenticated) {
      return const WishlistActionResult(
        failure: AuthFailure(message: 'Please log in to save favourites.'),
      );
    }

    final result = await ref.read(toggleWishlistUseCaseProvider).call(
          productId,
          isInWishlist: false,
        );

    return result.fold(
      (failure) => WishlistActionResult(failure: failure),
      (wishlist) {
        state = AsyncData(wishlist);
        return const WishlistActionResult();
      },
    );
  }

  Future<WishlistActionResult> moveAllToCart() async {
    if (!_isAuthenticated) {
      return const WishlistActionResult(
        failure: AuthFailure(message: 'Please log in to continue.'),
      );
    }

    if (_currentWishlist.items.isEmpty) {
      return const WishlistActionResult(movedCount: 0);
    }

    final result = await ref.read(moveWishlistToCartUseCaseProvider).call();
    if (result.isLeft()) {
      final failure = result.fold(
        (value) => value,
        (_) => const UnknownFailure(
          message: 'Unable to move wishlist items right now.',
        ),
      );
      return WishlistActionResult(
        failure: failure,
      );
    }

    final movedCount = result.fold((_) => 0, (count) => count);
    ref.invalidate(cartProvider);

    final refreshResult = await ref.read(getWishlistUseCaseProvider).call();
    refreshResult.fold(
      (_) {
        state = const AsyncData(WishlistEntity());
      },
      (wishlist) {
        state = AsyncData(wishlist);
      },
    );

    return WishlistActionResult(movedCount: movedCount);
  }

  void refresh() {
    ref.invalidateSelf();
  }

  bool get _isAuthenticated => ref.read(authStateProvider) is AuthAuthenticated;

  WishlistEntity get _currentWishlist => switch (state) {
        AsyncData(:final value) => value,
        _ => const WishlistEntity(),
      };
}
