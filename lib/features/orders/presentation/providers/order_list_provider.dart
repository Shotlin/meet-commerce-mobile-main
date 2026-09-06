import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/orders/data/datasources/order_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/orders/data/local/order_local_datasource.dart';
import 'package:bakaloo_flutter_app/features/orders/data/repositories/order_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/repositories/order_repository.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/usecases/cancel.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/usecases/download_invoice.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/usecases/get_active_order.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/usecases/get_detail.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/usecases/get_orders.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/usecases/reorder.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

enum OrderFilter {
  all,
  active,
  delivered,
  cancelled,
  failed,
}

extension OrderFilterX on OrderFilter {
  String get label => switch (this) {
        OrderFilter.all => 'All',
        OrderFilter.active => 'Active',
        OrderFilter.delivered => 'Delivered',
        OrderFilter.cancelled => 'Cancelled',
        OrderFilter.failed => 'Failed',
      };

  String? get statusParam => switch (this) {
        OrderFilter.all || OrderFilter.active || OrderFilter.failed => null,
        OrderFilter.delivered => 'DELIVERED',
        OrderFilter.cancelled => 'CANCELLED',
      };

  // Isolates expired/failed-payment cancellations into their own tab,
  // removed from All/Cancelled (see orders.repository.js#findByUser on the
  // backend) — never mixed in with a plain user/admin cancellation.
  bool get isPaymentFailedOnly => this == OrderFilter.failed;
}

final orderRemoteDataSourceProvider =
    Provider<OrderRemoteDataSource>((Ref ref) {
  return OrderRemoteDataSource(ref.watch(dioClientProvider));
});

final orderLocalDataSourceProvider = Provider<OrderLocalDataSource>((Ref ref) {
  return const OrderLocalDataSource();
});

final orderRepositoryProvider = Provider<OrderRepository>((Ref ref) {
  return OrderRepositoryImpl(
    remoteDataSource: ref.watch(orderRemoteDataSourceProvider),
    localDataSource: ref.watch(orderLocalDataSourceProvider),
  );
});

final getOrdersUseCaseProvider = Provider<GetOrdersUseCase>((Ref ref) {
  return GetOrdersUseCase(ref.watch(orderRepositoryProvider));
});

final getOrderDetailUseCaseProvider =
    Provider<GetOrderDetailUseCase>((Ref ref) {
  return GetOrderDetailUseCase(ref.watch(orderRepositoryProvider));
});

final getActiveOrderUseCaseProvider =
    Provider<GetActiveOrderUseCase>((Ref ref) {
  return GetActiveOrderUseCase(ref.watch(orderRepositoryProvider));
});

final cancelOrderUseCaseProvider = Provider<CancelOrderUseCase>((Ref ref) {
  return CancelOrderUseCase(ref.watch(orderRepositoryProvider));
});

final reorderUseCaseProvider = Provider<ReorderUseCase>((Ref ref) {
  return ReorderUseCase(ref.watch(orderRepositoryProvider));
});

final downloadInvoiceUseCaseProvider =
    Provider<DownloadInvoiceUseCase>((Ref ref) {
  return DownloadInvoiceUseCase(ref.watch(orderRepositoryProvider));
});

final orderListControllerProvider = Provider<OrderListController>((Ref ref) {
  return OrderListController(ref);
});

class OrderListController {
  const OrderListController(this._ref);

  final Ref _ref;

  Future<Either<Failure, OrderPageResult>> fetchPage({
    required OrderFilter filter,
    required int page,
    int limit = 10,
  }) async {
    if (filter == OrderFilter.active) {
      final activeResult =
          await _ref.read(getActiveOrderUseCaseProvider).call();
      return activeResult.fold(
        Left.new,
        (activeOrder) {
          if (page > 1 || activeOrder == null) {
            return Right(
              OrderPageResult(
                orders: <OrderEntity>[],
                pagination: PaginationEntity(
                  page: page,
                  limit: limit,
                  total: activeOrder == null ? 0 : 1,
                  totalPages: activeOrder == null ? 0 : 1,
                ),
              ),
            );
          }
          return Right(
            OrderPageResult(
              orders: <OrderEntity>[activeOrder],
              pagination: PaginationEntity(
                page: 1,
                limit: limit,
                total: 1,
                totalPages: 1,
              ),
            ),
          );
        },
      );
    }

    final listResult = await _ref.read(getOrdersUseCaseProvider).call(
          page: page,
          limit: limit,
          status: filter.statusParam,
          paymentFailed: filter.isPaymentFailedOnly,
        );

    if (filter != OrderFilter.all || page != 1) {
      return listResult;
    }

    final baseResult = listResult.fold<OrderPageResult?>(
      (_) => null,
      (result) => result,
    );
    if (baseResult == null) {
      return listResult;
    }

    final activeResult = await _ref.read(getActiveOrderUseCaseProvider).call();
    return activeResult.fold(
      (_) => Right(baseResult),
      (activeOrder) => Right(_pinActiveOrder(baseResult, activeOrder)),
    );
  }

  Future<Either<Failure, OrderEntity>> cancelOrder(
    String orderId, {
    String? reason,
  }) {
    return _ref.read(cancelOrderUseCaseProvider).call(orderId, reason: reason);
  }

  Future<Either<Failure, ReorderResult>> reorder(String orderId) {
    return _ref.read(reorderUseCaseProvider).call(orderId);
  }

  Future<Either<Failure, InvoiceFileResult>> downloadInvoice(String orderId) {
    return _ref.read(downloadInvoiceUseCaseProvider).call(orderId);
  }

  OrderPageResult _pinActiveOrder(
    OrderPageResult pageResult,
    OrderEntity? activeOrder,
  ) {
    if (activeOrder == null) {
      return pageResult;
    }

    final nextList = pageResult.orders.toList(growable: true)
      ..removeWhere((order) => order.id == activeOrder.id)
      ..insert(0, activeOrder);

    return OrderPageResult(
      orders: List<OrderEntity>.unmodifiable(nextList),
      pagination: pageResult.pagination,
      isStale: pageResult.isStale,
    );
  }
}
