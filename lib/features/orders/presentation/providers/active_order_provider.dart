import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_list_provider.dart';

// autoDispose for the same reason as orderDetailProvider: a plain
// FutureProvider caches its resolved value forever once fetched, so
// if the socket-driven invalidation in order_live_sync_provider ever
// misses an event (dropped connection, backgrounded app), this would
// keep serving a stale "active order" snapshot indefinitely instead
// of refetching when a widget starts watching it again.
final activeOrderProvider =
    FutureProvider.autoDispose<OrderEntity?>((Ref ref) async {
  final isAuthenticated = ref.watch(authStateProvider) is AuthAuthenticated;
  if (!isAuthenticated) {
    return null;
  }

  final result = await ref.read(getActiveOrderUseCaseProvider).call();
  return result.fold(
    (failure) => throw StateError(failure.message),
    (order) => order,
  );
});
