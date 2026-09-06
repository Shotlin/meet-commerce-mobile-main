import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/features/orders/data/models/order_model.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

class OrderRemoteDataSource {
  const OrderRemoteDataSource(this._dio);

  final Dio _dio;

  Future<OrderPageRemoteResult> getOrders({
    required int page,
    required int limit,
    String? status,
    bool paymentFailed = false,
  }) async {
    final response = await _dio.get<dynamic>(
      ApiConstants.orders,
      queryParameters: <String, dynamic>{
        'page': page,
        'limit': limit,
        // paymentFailed overrides status server-side (see
        // orders.repository.js#findByUser) — send status too, harmlessly
        // ignored, so callers don't need to remember to omit it.
        if (status != null && status.trim().isNotEmpty) 'status': status,
        if (paymentFailed) 'paymentFailed': true,
      },
    );
    final payload = _parsePayload(response.data, ApiConstants.orders);
    final items = payload['data'];
    final paginationRaw = payload['pagination'];

    final orders = items is List
        ? items
            .whereType<Map>()
            .map((item) => OrderModel.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false)
        : const <OrderModel>[];

    final pagination = paginationRaw is Map
        ? PaginationEntity.fromJson(Map<String, dynamic>.from(paginationRaw))
        : PaginationEntity(
            page: page,
            limit: limit,
            total: orders.length,
            totalPages: orders.isEmpty ? 0 : 1,
          );

    return OrderPageRemoteResult(
      orders: orders,
      pagination: pagination,
    );
  }

  Future<OrderModel?> getActiveOrder() async {
    try {
      final response = await _dio.get<dynamic>(ApiConstants.ordersActive);
      final payload = _parsePayload(response.data, ApiConstants.ordersActive);
      final data = payload['data'];
      if (data is! Map) {
        return null;
      }
      return OrderModel.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<OrderModel> getOrderDetail(String orderId) async {
    final path = ApiConstants.orderById(orderId);
    final response = await _dio.get<dynamic>(path);
    final payload = _parsePayload(response.data, path);
    final data = payload['data'];
    if (data is! Map) {
      throw _badResponse(path, payload);
    }
    return OrderModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<OrderModel> cancelOrder(
    String orderId, {
    String? reason,
  }) async {
    final path = ApiConstants.orderCancel(orderId);
    final response = await _dio.post<dynamic>(
      path,
      data: <String, dynamic>{
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    final payload = _parsePayload(response.data, path);
    final data = payload['data'];
    if (data is! Map) {
      throw _badResponse(path, payload);
    }
    return OrderModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<ReorderRemoteResult> reorder(String orderId) async {
    final path = ApiConstants.orderReorder(orderId);
    final response = await _dio.post<dynamic>(path, data: <String, dynamic>{});
    final payload = _parsePayload(response.data, path);
    final data = payload['data'];

    final cartMap = data is Map ? Map<String, dynamic>.from(data) : null;
    final items = cartMap?['items'];
    final itemCount = _readInt(
      cartMap ?? const <String, dynamic>{},
      <String>['itemCount', 'item_count'],
      fallback: items is List ? items.length : 0,
    );

    final warningsRaw = payload['warnings'];
    final warnings = warningsRaw is List
        ? warningsRaw
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    return ReorderRemoteResult(
      itemCount: itemCount,
      warnings: warnings,
    );
  }

  Future<InvoiceRemoteResult> downloadInvoice(String orderId) async {
    final path = ApiConstants.orderInvoice(orderId);
    final response = await _dio.get<dynamic>(
      path,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data is! List<int>) {
      throw _badResponse(path, data);
    }

    final disposition = response.headers.value('content-disposition') ?? '';
    final fileName = _extractFileName(disposition) ?? 'invoice-$orderId.pdf';

    return InvoiceRemoteResult(
      bytes: Uint8List.fromList(data),
      fileName: fileName,
    );
  }

  Map<String, dynamic> _parsePayload(dynamic raw, String path) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    throw _badResponse(path, raw);
  }

  DioException _badResponse(String path, dynamic raw) {
    return DioException.badResponse(
      statusCode: 500,
      requestOptions: RequestOptions(path: path),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: path),
        statusCode: 500,
        data: raw,
      ),
    );
  }

  int _readInt(
    Map<String, dynamic> json,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String && value.trim().isNotEmpty) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return fallback;
  }

  String? _extractFileName(String contentDisposition) {
    if (contentDisposition.trim().isEmpty) {
      return null;
    }

    final match =
        RegExp(r'filename="?([^";]+)"?').firstMatch(contentDisposition);
    final fileName = match?.group(1)?.trim();
    if (fileName == null || fileName.isEmpty) {
      return null;
    }
    return fileName;
  }
}

class OrderPageRemoteResult {
  const OrderPageRemoteResult({
    required this.orders,
    required this.pagination,
  });

  final List<OrderModel> orders;
  final PaginationEntity pagination;
}

class ReorderRemoteResult {
  const ReorderRemoteResult({
    required this.itemCount,
    required this.warnings,
  });

  final int itemCount;
  final List<String> warnings;
}

class InvoiceRemoteResult {
  const InvoiceRemoteResult({
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;
}
