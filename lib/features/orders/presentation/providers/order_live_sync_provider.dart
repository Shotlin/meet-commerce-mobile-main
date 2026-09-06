import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/socket/socket_models/order_status_event.dart';
import 'package:bakaloo_flutter_app/features/orders/data/datasources/order_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/orders/data/local/order_local_datasource.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/active_order_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_detail_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_list_provider.dart';

final orderListRefreshTickProvider =
    NotifierProvider<OrderListRefreshTickNotifier, int>(
  OrderListRefreshTickNotifier.new,
);

final orderLiveSyncControllerProvider = Provider<OrderLiveSyncController>((
  Ref ref,
) {
  return OrderLiveSyncController(
    ref,
    remoteDataSource: ref.watch(orderRemoteDataSourceProvider),
    localDataSource: ref.watch(orderLocalDataSourceProvider),
  );
});

class OrderLiveSyncController {
  OrderLiveSyncController(
    this._ref, {
    required OrderRemoteDataSource remoteDataSource,
    required OrderLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  final Ref _ref;
  final OrderRemoteDataSource _remoteDataSource;
  final OrderLocalDataSource _localDataSource;

  Future<void> handleStatusEvent(OrderStatusEvent event) async {
    if (event.orderId.trim().isEmpty) {
      return;
    }

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

    await _localDataSource.invalidateAllListCaches();
    final detailProvider = orderDetailProvider(event.orderId);
    _ref
      ..invalidate(detailProvider)
      ..invalidate(activeOrderProvider);
    _ref.read(orderListRefreshTickProvider.notifier).bump();

    unawaited(_refreshFromRemote(event.orderId));
  }

  Future<void> _refreshFromRemote(String orderId) async {
    try {
      final detail = await _remoteDataSource.getOrderDetail(orderId);
      await _localDataSource.cacheOrderDetail(orderId, detail.toJson());
    } catch (_) {}

    try {
      final active = await _remoteDataSource.getActiveOrder();
      await _localDataSource.cacheActiveOrder(active?.toJson());
    } catch (_) {}

    final detailProvider = orderDetailProvider(orderId);
    _ref
      ..invalidate(detailProvider)
      ..invalidate(activeOrderProvider);
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
