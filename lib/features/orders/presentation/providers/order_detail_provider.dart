import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_list_provider.dart';

// autoDispose: a plain (non-disposing) family provider caches its
// resolved value forever once fetched, so reopening the same order
// later — e.g. after a rider cancels it outside this screen — would
// keep replaying the stale pre-cancellation snapshot rather than
// refetching. Socket-driven invalidation (order_live_sync_provider)
// only helps while connected; this guarantees a fresh fetch on every
// screen visit regardless of missed/late socket events.
final orderDetailProvider =
    FutureProvider.autoDispose.family<OrderEntity, String>((
  Ref ref,
  String orderId,
) async {
  final result = await ref.read(getOrderDetailUseCaseProvider).call(orderId);
  return result.fold(
    (failure) => throw StateError(failure.message),
    (order) => order,
  );
});
