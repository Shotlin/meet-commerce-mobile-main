import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

class OrderPageResult {
  const OrderPageResult({
    required this.orders,
    required this.pagination,
    this.isStale = false,
  });

  final List<OrderEntity> orders;
  final PaginationEntity pagination;
  final bool isStale;
}

class ReorderResult {
  const ReorderResult({
    required this.itemCount,
    required this.warnings,
  });

  final int itemCount;
  final List<String> warnings;
}

class InvoiceFileResult {
  const InvoiceFileResult({
    required this.path,
    required this.fileName,
  });

  final String path;
  final String fileName;
}

abstract class OrderRepository {
  Future<Either<Failure, OrderPageResult>> getOrders({
    int page = 1,
    int limit = 10,
    String? status,
    bool paymentFailed = false,
  });

  Future<Either<Failure, OrderEntity?>> getActiveOrder();

  Future<Either<Failure, OrderEntity>> getOrderDetail(String orderId);

  Future<Either<Failure, OrderEntity>> cancelOrder(
    String orderId, {
    String? reason,
  });

  Future<Either<Failure, ReorderResult>> reorder(String orderId);

  Future<Either<Failure, InvoiceFileResult>> downloadInvoice(String orderId);
}
