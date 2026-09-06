import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/products/data/models/product_model.dart';
import 'package:bakaloo_flutter_app/features/wishlist/domain/entities/wishlist_entity.dart';

class WishlistRemoteDataSource {
  const WishlistRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<WishlistEntity> getWishlist() async {
    final response = await _apiClient.getWishlist();
    final payload = _parsePayload(response.data, ApiConstants.wishlist);
    final data = payload['data'];

    List<dynamic> itemsRaw = const <dynamic>[];
    var total = 0;

    if (data is List) {
      itemsRaw = data;
      total = data.length;
    } else if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final nested = map['items'];
      if (nested is List) {
        itemsRaw = nested;
      }
      total = _toInt(map['total']) ?? itemsRaw.length;
    }

    final items = itemsRaw
        .whereType<Map>()
        .map((rawItem) => Map<String, dynamic>.from(rawItem))
        .map(_toWishlistItem)
        .whereType<WishlistItemEntity>()
        .toList(growable: false);

    return WishlistEntity(
      items: items,
      total: total <= 0 ? items.length : total,
    );
  }

  Future<void> addItem(String productId) async {
    try {
      await _apiClient.addWishlistItem(productId);
    } on DioException catch (error) {
      final code = error.response?.statusCode;
      if (code == 404 || code == 405 || code == 400) {
        await _apiClient.addWishlistItemByBody(
          <String, dynamic>{'productId': productId},
        );
        return;
      }
      rethrow;
    }
  }

  Future<void> removeItem(String productId) {
    return _apiClient.removeWishlistItem(productId);
  }

  Future<int> moveToCart() async {
    // Pass an empty body so the backend does not reject with
    // "Body cannot be empty when content-type is application/json"
    final response = await _apiClient.moveWishlistToCart(
      const <String, dynamic>{},
    );
    final payload =
        _parsePayload(response.data, ApiConstants.wishlistMoveToCart);
    final data = payload['data'];

    if (data is int) {
      return data;
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      return _toInt(map['movedCount']) ?? _toInt(map['count']) ?? 0;
    }
    return 0;
  }

  WishlistItemEntity? _toWishlistItem(Map<String, dynamic> raw) {
    final productModel = ProductModel.fromJson(raw);
    final productId =
        _readString(raw, <String>['product_id', 'productId', 'id']);
    if (productId.isEmpty || productModel.id.isEmpty) {
      return null;
    }

    return WishlistItemEntity(
      productId: productId,
      product: productModel.toEntity(),
      addedAt: _readDateTime(raw, <String>['wishlist_added_at', 'created_at']),
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

  int? _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  String _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  DateTime? _readDateTime(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }
}
