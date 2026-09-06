import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/socket/socket_models/order_status_event.dart';
import 'package:bakaloo_flutter_app/features/tracking/presentation/providers/tracking_provider.dart';

part 'order_status_stream_provider.g.dart';

@riverpod
Stream<OrderStatusEvent> orderStatusStream(Ref ref) {
  return ref.watch(trackingRepositoryProvider).watchOrderStatus();
}
