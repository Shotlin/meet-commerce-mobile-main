import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/checkout/data/models/order_model.dart';

class OrderRemoteDataSource {
  const OrderRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<OrderModel> placeOrder(Map<String, dynamic> body) async {
    final response = await _apiClient.placeOrder(body);
    final payload = _parsePayload(response.data, ApiConstants.orders);
    final data = payload['data'];
    if (data is! Map) {
      throw DioException.badResponse(
        statusCode: 500,
        requestOptions: RequestOptions(path: ApiConstants.orders),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: ApiConstants.orders),
          statusCode: 500,
          data: payload,
        ),
      );
    }

    final dataMap = Map<String, dynamic>.from(data);

    // Backend returns { orders: [...], order: {...} }.
    // Parse the single `order` object (first per-shop order).
    final orderJson = dataMap['order'] ?? dataMap;
    if (orderJson is Map) {
      return OrderModel.fromJson(Map<String, dynamic>.from(orderJson));
    }

    // Fallback: try parsing from the orders array
    final ordersArray = dataMap['orders'];
    if (ordersArray is List && ordersArray.isNotEmpty && ordersArray.first is Map) {
      return OrderModel.fromJson(Map<String, dynamic>.from(ordersArray.first));
    }

    return OrderModel.fromJson(dataMap);
  }

  Map<String, dynamic> _parsePayload(dynamic raw, String path) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    throw DioException.badResponse(
      statusCode: 500,
      requestOptions: RequestOptions(path: path),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: path),
        statusCode: 500,
        data: raw,
      ),
    );
  }
}
