import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/features/orders/data/datasources/order_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/orders/data/local/order_local_datasource.dart';
import 'package:bakaloo_flutter_app/features/orders/data/models/order_model.dart';
import 'package:bakaloo_flutter_app/features/orders/data/repositories/order_repository_impl.dart';

/// Regression: a cached TERMINAL order (DELIVERED / CANCELLED / REFUNDED) used
/// to be returned as "fresh" with only a silent background refresh, so a
/// status that changed afterwards — DELIVERED → REFUNDED — showed the OLD
/// status until the app was reopened. Reads are now network-first.
class _FakeRemote extends OrderRemoteDataSource {
  _FakeRemote() : super(Dio());
  int detailCalls = 0;
  bool fail = false;
  String status = 'REFUNDED';

  @override
  Future<OrderModel> getOrderDetail(String orderId) async {
    detailCalls++;
    if (fail) throw DioException(requestOptions: RequestOptions(path: '/x'));
    return OrderModel.fromJson(_json(orderId, status));
  }
}

class _FakeLocal extends OrderLocalDataSource {
  _FakeLocal(this.cachedDetail);
  Map<String, dynamic>? cachedDetail;

  @override
  Map<String, dynamic>? getCachedOrderDetail(String orderId) => cachedDetail;
  @override
  bool isFresh(String key, Duration ttl) => true; // the stale-forever trap
  @override
  Future<void> cacheOrderDetail(String orderId, Map<String, dynamic> json) async {
    cachedDetail = json;
  }
}

Map<String, dynamic> _json(String id, String status) => <String, dynamic>{
      'id': id,
      'orderNumber': 'FC-1',
      'status': status,
      'items': <dynamic>[],
      'subtotal': 10.0,
      'discount': 0.0,
      'deliveryFee': 0.0,
      'platformFee': 0.0,
      'total': 10.0,
      'deliveryAddress': <String, dynamic>{},
      'paymentMethod': 'COD',
      'paymentStatus': 'PAID',
      'createdAt': '2026-09-23T11:15:46.362Z',
    };

void main() {
  test('a fresh cached DELIVERED order does NOT hide the real REFUNDED status', () async {
    final remote = _FakeRemote();
    final repo = OrderRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: _FakeLocal(_json('o1', 'DELIVERED')),
    );
    final result = await repo.getOrderDetail('o1');
    expect(remote.detailCalls, 1, reason: 'must hit the network, not trust the cache');
    expect(result.fold((_) => null, (o) => o.status.name), 'REFUNDED');
  });

  test('the cache is still the OFFLINE fallback', () async {
    final remote = _FakeRemote()..fail = true;
    final repo = OrderRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: _FakeLocal(_json('o1', 'DELIVERED')),
    );
    final result = await repo.getOrderDetail('o1');
    expect(result.fold((_) => null, (o) => o.status.name), 'DELIVERED');
  });
}
