import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/cart/data/models/cart_item_model.dart';
import 'package:bakaloo_flutter_app/features/cart/data/models/cart_model.dart';

class CartValidationRemoteResult {
  const CartValidationRemoteResult({
    required this.valid,
    required this.cart,
    required this.warnings,
  });

  final bool valid;
  final CartModel cart;
  final List<String> warnings;
}

class CartRemoteDataSource {
  const CartRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<CartModel> getCart() async {
    final response = await _apiClient.getCart();
    return _parseCartResponse(response.data, ApiConstants.cart);
  }

  Future<CartModel> addItem({
    required String productId,
    required int quantity,
    String? shopProductId,
  }) async {
    final body = <String, dynamic>{
      'productId': productId,
      'quantity': quantity,
    };
    if (shopProductId != null) {
      body['shopProductId'] = shopProductId;
    }
    final response = await _apiClient.addCartItem(body);
    return _parseCartResponse(response.data, ApiConstants.cartItems);
  }

  Future<CartModel> updateItem({
    required String productId,
    required int quantity,
    String? shopProductId,
  }) async {
    final body = <String, dynamic>{'quantity': quantity};
    if (shopProductId != null) {
      body['shopProductId'] = shopProductId;
    }
    final response = await _apiClient.updateCartItem(
      productId,
      body,
    );
    return _parseCartResponse(
      response.data,
      ApiConstants.cartItem(productId),
    );
  }

  Future<CartModel> removeItem(String productId, {String? shopProductId}) async {
    final response = await _apiClient.removeCartItem(
      productId,
      shopProductId: shopProductId,
    );
    return _parseCartResponse(
      response.data,
      ApiConstants.cartItem(productId),
    );
  }

  Future<void> clearCart() async {
    await _apiClient.clearCart();
  }

  Future<CartValidationRemoteResult> validateCart() async {
    final response = await _apiClient.validateCart(const <String, dynamic>{});
    final payload = _parsePayload(response.data, ApiConstants.cartValidate);
    final data = payload['data'];

    if (data is! Map) {
      throw DioException.badResponse(
        statusCode: 500,
        requestOptions: RequestOptions(path: ApiConstants.cartValidate),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: ApiConstants.cartValidate),
          statusCode: 500,
          data: payload,
        ),
      );
    }

    final json = Map<String, dynamic>.from(data);
    final items = (json['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (item) => CartItemModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
    final subtotal = _toDouble(json['subtotal']);
    final itemCount = items.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final warnings = (json['warnings'] as List<dynamic>? ?? const <dynamic>[])
        .map((warning) => warning.toString())
        .where((warning) => warning.trim().isNotEmpty)
        .toList();

    return CartValidationRemoteResult(
      valid: json['valid'] as bool? ?? false,
      cart: CartModel(
        items: items,
        subtotal: subtotal,
        itemCount: itemCount,
      ),
      warnings: warnings,
    );
  }

  CartModel _parseCartResponse(dynamic raw, String path) {
    final payload = _parsePayload(raw, path);
    final data = payload['data'];
    if (data is! Map) {
      return const CartModel();
    }

    return CartModel.fromJson(Map<String, dynamic>.from(data));
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

  double _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
