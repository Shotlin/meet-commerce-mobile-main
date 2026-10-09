import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/socket/order_event_gate.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_models/order_status_event.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_models/refund_status_event.dart';
import 'package:bakaloo_flutter_app/features/orders/data/local/order_local_datasource.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/active_order_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_detail_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_list_provider.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/presentation/providers/refund_request_provider.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';

final orderListRefreshTickProvider =
    NotifierProvider<OrderListRefreshTickNotifier, int>(
  OrderListRefreshTickNotifier.new,
);

final orderLiveSyncControllerProvider = Provider<OrderLiveSyncController>((
  Ref ref,
) {
  return OrderLiveSyncController(
    ref,
    localDataSource: ref.watch(orderLocalDataSourceProvider),
  );
});

class OrderLiveSyncController {
  OrderLiveSyncController(
    this._ref, {
    required OrderLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  final Ref _ref;
  final OrderLocalDataSource _localDataSource;

  // Drops duplicate / out-of-order realtime events (see OrderEventGate).
  final OrderEventGate _gate = OrderEventGate();
  DateTime? _lastReconcileAt;

  Future<void> handleStatusEvent(OrderStatusEvent event) async {
    if (event.orderId.trim().isEmpty) {
      return;
    }
    if (!_gate.accept(
      key: 'order:${event.orderId}',
      seq: event.seq,
      eventId: event.eventId,
    )) {
      return;
    }

    // Paint the new status instantly from the event itself (also the offline
    // fallback if the confirming read below fails)...
    final patchedDetail = _mergeOrderJson(
      _localDataSource.getCachedOrderDetail(event.orderId),
      event,
    );
    if (patchedDetail != null) {
      await _localDataSource.cacheOrderDetail(event.orderId, patchedDetail);
    }

    final Map<String, dynamic>? activeOrder =
        _localDataSource.getCachedActiveOrder();
    final activeOrderId = '${activeOrder?['id'] ?? ''}';
    if (activeOrderId == event.orderId) {
      if (event.status.isActive) {
        final patchedActive = _mergeOrderJson(activeOrder, event);
        await _localDataSource.cacheActiveOrder(patchedActive);
      } else {
        await _localDataSource.cacheActiveOrder(null);
      }
    }

    // ...then ONE authoritative refetch per event: the providers read
    // network-first, so invalidating them is the confirming REST read (the
    // old extra `_refreshFromRemote` made every event cost 2-3 requests).
    await _localDataSource.invalidateAllListCaches();
    _ref
      ..invalidate(orderDetailProvider(event.orderId))
      ..invalidate(activeOrderProvider)
      ..invalidate(refundRequestByOrderProvider(event.orderId));
    _ref.read(orderListRefreshTickProvider.notifier).bump();
  }

  /// `refund:status` — a refund request on one of this customer's orders
  /// changed. Refreshes the request card, the order (an approved full
  /// refund flips it to REFUNDED) and, for wallet refunds, the balance.
  Future<void> handleRefundEvent(RefundStatusEvent event) async {
    if (!_gate.accept(
      key: 'refund:${event.refundRequestId}',
      seq: event.seq,
      eventId: event.eventId,
    )) {
      return;
    }
    await _localDataSource.invalidateAllListCaches();
    _ref
      ..invalidate(refundRequestByOrderProvider(event.orderId))
      ..invalidate(orderDetailProvider(event.orderId))
      ..invalidate(activeOrderProvider);
    if (event.isApproved && event.refundTo != 'RAZORPAY') {
      _ref.invalidate(walletProvider);
    }
    _ref.read(orderListRefreshTickProvider.notifier).bump();
  }

  /// Push-triggered sync (an FCM message about this order arrived): the push
  /// already carries "something changed", so just re-read it. Works even
  /// when the socket is down.
  Future<void> syncOrder(String orderId, {bool wallet = false}) async {
    if (orderId.trim().isEmpty) return;
    await _localDataSource.invalidateAllListCaches();
    _ref
      ..invalidate(orderDetailProvider(orderId))
      ..invalidate(activeOrderProvider)
      ..invalidate(refundRequestByOrderProvider(orderId));
    if (wallet) _ref.invalidate(walletProvider);
    _ref.read(orderListRefreshTickProvider.notifier).bump();
  }

  /// Full re-read of everything order-related. Fired on app resume and on
  /// every socket (re)connect — events published while the app was
  /// backgrounded/disconnected are never replayed, so this is what makes
  /// the app converge. Throttled so resume + reconnect firing together cost
  /// one round of requests, not two.
  Future<void> reconcile() async {
    final now = DateTime.now();
    final last = _lastReconcileAt;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      return;
    }
    _lastReconcileAt = now;
    await _localDataSource.invalidateAllListCaches();
    _ref
      ..invalidate(orderDetailProvider)
      ..invalidate(activeOrderProvider)
      ..invalidate(refundRequestByOrderProvider);
    _ref.read(orderListRefreshTickProvider.notifier).bump();
  }

  Map<String, dynamic>? _mergeOrderJson(
    Map<String, dynamic>? rawOrder,
    OrderStatusEvent event,
  ) {
    if (rawOrder == null) {
      return null;
    }

    final next = Map<String, dynamic>.from(rawOrder);
    final timeline = ((next['timeline'] as List<dynamic>?) ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: true);

    final timelineItem = <String, dynamic>{
      'type': event.timelineType.name,
      'status': event.status.name,
      'timestamp': event.timestamp.toIso8601String(),
      'message': event.message,
    };

    final existingIndex = timeline.indexWhere((entry) {
      final type = '${entry['type'] ?? entry['timelineType'] ?? ''}'.trim();
      return type == event.timelineType.name;
    });

    if (existingIndex >= 0) {
      timeline[existingIndex] = timelineItem;
    } else {
      timeline.add(timelineItem);
    }

    timeline.sort((left, right) {
      final leftTime = DateTime.tryParse('${left['timestamp'] ?? ''}');
      final rightTime = DateTime.tryParse('${right['timestamp'] ?? ''}');
      return (leftTime ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(rightTime ?? DateTime.fromMillisecondsSinceEpoch(0));
    });

    next['status'] = event.status.name;
    next['updatedAt'] = event.timestamp.toIso8601String();
    next['updated_at'] = event.timestamp.toIso8601String();
    next['timeline'] = timeline;
    return next;
  }
}

class OrderListRefreshTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() {
    state = state + 1;
  }
}
