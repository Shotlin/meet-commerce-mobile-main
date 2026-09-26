import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_quality_videos_result.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_list_provider.dart';

/// Fetched fresh every time a scan resolves an order — autoDispose (torn
/// down once the video screen closes) since there's nothing worth keeping
/// warm here: a scan is a one-off action, not a screen someone reopens
/// repeatedly the way Order Details is. Keyed by `orderId`, so a
/// different scanned order is always a genuinely fresh network call —
/// never a stale/cached result from whatever order was viewed before.
final orderQualityVideosProvider = FutureProvider.autoDispose
    .family<OrderQualityVideosResult, String>((Ref ref, String orderId) async {
  final result = await ref.read(getOrderQualityVideosUseCaseProvider).call(orderId);
  return result.fold(
    (failure) => throw StateError(failure.message),
    (data) => data,
  );
});
