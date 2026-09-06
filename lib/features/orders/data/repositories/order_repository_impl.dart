import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/orders/data/datasources/order_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/orders/data/local/order_local_datasource.dart';
import 'package:bakaloo_flutter_app/features/orders/data/models/order_model.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/repositories/order_repository.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

class OrderRepositoryImpl implements OrderRepository {
  const OrderRepositoryImpl({
    required OrderRemoteDataSource remoteDataSource,
    required OrderLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  final OrderRemoteDataSource _remoteDataSource;
  final OrderLocalDataSource _localDataSource;

  @override
  Future<Either<Failure, OrderPageResult>> getOrders({
    int page = 1,
    int limit = 10,
    String? status,
    bool paymentFailed = false,
  }) async {
    // 'failed' must be its own cache bucket — it shares status == null with
    // the 'all' filter, and without this they'd read/write the same cache
    // entry (the Failed tab briefly showing "All"'s cached orders, or
    // vice versa).
    final cacheKey = _localDataSource.listCacheKey(
      filterKey: paymentFailed ? 'failed' : (status ?? 'all').toLowerCase(),
      page: page,
      limit: limit,
    );

    final cached = _cachedPage(cacheKey);
    final isFresh =
        _localDataSource.isFresh(cacheKey, OrderLocalDataSource.ttl);

    if (page == 1 && cached != null && isFresh) {
      unawaited(
        _refreshFirstPage(
          cacheKey: cacheKey,
          page: page,
          limit: limit,
          status: status,
          paymentFailed: paymentFailed,
        ),
      );
      return Right(cached);
    }

    try {
      final remote = await _remoteDataSource.getOrders(
        page: page,
        limit: limit,
        status: status,
        paymentFailed: paymentFailed,
      );
      final result = OrderPageResult(
        orders: remote.orders
            .map((order) => order.toEntity())
            .toList(growable: false),
        pagination: remote.pagination,
      );

      if (page == 1) {
        await _localDataSource.cacheOrderList(
          key: cacheKey,
          items: remote.orders
              .map((order) => order.toJson())
              .toList(growable: false),
          pagination: remote.pagination,
        );
      }

      return Right(result);
    } on DioException catch (error) {
      if (page == 1 && cached != null) {
        return Right(
          OrderPageResult(
            orders: cached.orders,
            pagination: cached.pagination,
            isStale: true,
          ),
        );
      }
      return Left(handleDioError(error));
    } catch (_) {
      if (page == 1 && cached != null) {
        return Right(
          OrderPageResult(
            orders: cached.orders,
            pagination: cached.pagination,
            isStale: true,
          ),
        );
      }
      return const Left(
        UnknownFailure(message: 'Unable to load orders right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, OrderEntity?>> getActiveOrder() async {
    final cacheKey = _localDataSource.activeCacheKey;
    final cached = _cachedActiveOrder();
    final isFresh =
        _localDataSource.isFresh(cacheKey, OrderLocalDataSource.ttl);

    if (cached != null && isFresh && !cached.isActive) {
      unawaited(_refreshActiveOrder());
      return Right(cached);
    }

    try {
      final remote = await _remoteDataSource.getActiveOrder();
      await _localDataSource.cacheActiveOrder(remote?.toJson());
      return Right(remote?.toEntity());
    } on DioException catch (error) {
      if (cached != null) {
        return Right(cached);
      }
      return Left(handleDioError(error));
    } catch (_) {
      if (cached != null) {
        return Right(cached);
      }
      return const Left(
        UnknownFailure(message: 'Unable to load active order right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> getOrderDetail(String orderId) async {
    final cacheKey = _localDataSource.detailCacheKey(orderId);
    final cached = _cachedOrderDetail(orderId);
    final isFresh =
        _localDataSource.isFresh(cacheKey, OrderLocalDataSource.ttl);

    if (cached != null && isFresh && !cached.isActive) {
      unawaited(_refreshOrderDetail(orderId));
      return Right(cached);
    }

    try {
      final remote = await _remoteDataSource.getOrderDetail(orderId);
      await _localDataSource.cacheOrderDetail(orderId, remote.toJson());
      return Right(remote.toEntity());
    } on DioException catch (error) {
      if (cached != null) {
        return Right(cached);
      }
      return Left(handleDioError(error));
    } catch (_) {
      if (cached != null) {
        return Right(cached);
      }
      return const Left(
        UnknownFailure(message: 'Unable to load order details right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> cancelOrder(
    String orderId, {
    String? reason,
  }) async {
    try {
      final remote = await _remoteDataSource.cancelOrder(
        orderId,
        reason: reason,
      );
      await _localDataSource.invalidateOrder(orderId);
      await _localDataSource.invalidateAllListCaches();
      await _localDataSource.cacheOrderDetail(orderId, remote.toJson());
      await _localDataSource.cacheActiveOrder(null);
      return Right(remote.toEntity());
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to cancel this order right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, ReorderResult>> reorder(String orderId) async {
    try {
      final result = await _remoteDataSource.reorder(orderId);
      return Right(
        ReorderResult(
          itemCount: result.itemCount,
          warnings: result.warnings,
        ),
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to reorder items right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, InvoiceFileResult>> downloadInvoice(
    String orderId,
  ) async {
    try {
      final invoice = await _remoteDataSource.downloadInvoice(orderId);
      final tempDir = await getTemporaryDirectory();
      final sanitizedName = _safeInvoiceFileName(invoice.fileName, orderId);
      final file = File('${tempDir.path}/$sanitizedName');
      await file.writeAsBytes(invoice.bytes, flush: true);
      return Right(
        InvoiceFileResult(
          path: file.path,
          fileName: sanitizedName,
        ),
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to download the invoice right now.'),
      );
    }
  }

  /// Builds a safe, traversal-proof invoice filename.
  ///
  /// The server's `Content-Disposition` filename is untrusted input: it could
  /// contain path separators or `..` segments. We strip everything but the base
  /// name, allow-list characters, and always force a `.pdf` extension.
  String _safeInvoiceFileName(String rawName, String orderId) {
    final base = rawName.split(RegExp(r'[\\/]')).last.trim();
    var cleaned = base
        .replaceAll('..', '')
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    if (cleaned.toLowerCase().endsWith('.pdf')) {
      cleaned = cleaned.substring(0, cleaned.length - 4);
    }
    if (cleaned.isEmpty || cleaned == '_') {
      cleaned = 'invoice-$orderId';
    }
    return '$cleaned.pdf';
  }

  OrderPageResult? _cachedPage(String cacheKey) {
    final cached = _localDataSource.getCachedOrderList(cacheKey);
    if (cached == null) {
      return null;
    }

    final items = (cached['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => OrderModel.fromJson(Map<String, dynamic>.from(item)))
        .map((item) => item.toEntity())
        .toList(growable: false);

    final paginationRaw = cached['pagination'];
    if (paginationRaw is! Map) {
      return null;
    }

    return OrderPageResult(
      orders: items,
      pagination:
          PaginationEntity.fromJson(Map<String, dynamic>.from(paginationRaw)),
    );
  }

  OrderEntity? _cachedOrderDetail(String orderId) {
    final cached = _localDataSource.getCachedOrderDetail(orderId);
    if (cached == null) {
      return null;
    }
    return OrderModel.fromJson(cached).toEntity();
  }

  OrderEntity? _cachedActiveOrder() {
    final cached = _localDataSource.getCachedActiveOrder();
    if (cached == null) {
      return null;
    }
    return OrderModel.fromJson(cached).toEntity();
  }

  Future<void> _refreshFirstPage({
    required String cacheKey,
    required int page,
    required int limit,
    required String? status,
    bool paymentFailed = false,
  }) async {
    try {
      final remote = await _remoteDataSource.getOrders(
        page: page,
        limit: limit,
        status: status,
        paymentFailed: paymentFailed,
      );
      await _localDataSource.cacheOrderList(
        key: cacheKey,
        items:
            remote.orders.map((item) => item.toJson()).toList(growable: false),
        pagination: remote.pagination,
      );
    } catch (_) {}
  }

  Future<void> _refreshOrderDetail(String orderId) async {
    try {
      final remote = await _remoteDataSource.getOrderDetail(orderId);
      await _localDataSource.cacheOrderDetail(orderId, remote.toJson());
    } catch (_) {}
  }

  Future<void> _refreshActiveOrder() async {
    try {
      final remote = await _remoteDataSource.getActiveOrder();
      await _localDataSource.cacheActiveOrder(remote?.toJson());
    } catch (_) {}
  }
}
