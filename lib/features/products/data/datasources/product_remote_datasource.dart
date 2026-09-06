import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/products/data/models/product_model.dart';
import 'package:bakaloo_flutter_app/features/products/data/models/product_options_response.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

class ProductRemotePage {
  const ProductRemotePage({
    required this.items,
    required this.pagination,
  });

  final List<ProductModel> items;
  final PaginationEntity pagination;
}

class ProductRemoteDataSource {
  const ProductRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<ProductRemotePage> getProducts({
    required int page,
    required int limit,
    bool groupOptions = true,
  }) async {
    final response = await _apiClient.getProducts(
      page,
      limit,
      groupOptions: groupOptions ? true : null,
    );
    return _parsePage(Map<String, dynamic>.from(response.data as Map));
  }

  Future<ProductModel> getProductDetail(String productId) async {
    final response = await _apiClient.getProductDetail(productId);
    final payload = response.data;
    if (payload is! Map) {
      throw DioException.badResponse(
        statusCode: 500,
        requestOptions: RequestOptions(path: '/products/$productId'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/products/$productId'),
          statusCode: 500,
        ),
      );
    }

    final json = Map<String, dynamic>.from(payload);
    final data = json['data'];
    if (data is! Map) {
      throw DioException.badResponse(
        statusCode: 500,
        requestOptions: RequestOptions(path: '/products/$productId'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/products/$productId'),
          statusCode: 500,
          data: payload,
        ),
      );
    }

    return ProductModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<ProductModel>> getFeatured({int limit = 12}) async {
    final response = await _apiClient.getFeaturedProducts(limit);
    return _parseList(response.data);
  }

  Future<List<ProductModel>> getNewArrivals({int limit = 12}) async {
    final response = await _apiClient.getNewArrivalProducts(limit);
    return _parseList(response.data);
  }

  Future<List<ProductModel>> getDeals({int limit = 12}) async {
    final response = await _apiClient.getDealProducts(limit);
    return _parseList(response.data);
  }

  Future<List<ProductModel>> getRelated(
    String productId, {
    int limit = 8,
  }) async {
    final response = await _apiClient.getRelatedProducts(productId, limit);
    return _parseList(response.data);
  }

  Future<List<ProductModel>> getPairWith(
    String productId, {
    int limit = 10,
  }) async {
    final response = await _apiClient.getPairWithProducts(productId, limit);
    return _parseList(response.data);
  }

  ProductRemotePage _parsePage(Map<String, dynamic> json) {
    final items = _parseList(json['data']);
    final paginationJson = json['pagination'];
    final pagination = paginationJson is Map
        ? PaginationEntity.fromJson(
            Map<String, dynamic>.from(paginationJson),
          )
        : const PaginationEntity(page: 1, limit: 20, total: 0, totalPages: 0);

    return ProductRemotePage(items: items, pagination: pagination);
  }

  List<ProductModel> _parseList(dynamic rawList) {
    if (rawList is! List) {
      return const <ProductModel>[];
    }

    return rawList
        .whereType<Map>()
        .map(
          (Map item) => ProductModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<ProductOptionsResponse> getProductOptions(String productId) async {
    final response = await _apiClient.getProductOptions(productId);
    final payload = response.data;
    if (payload is! Map) {
      throw DioException.badResponse(
        statusCode: 500,
        requestOptions: RequestOptions(path: '/products/$productId/options'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/products/$productId/options'),
          statusCode: 500,
        ),
      );
    }
    final json = Map<String, dynamic>.from(payload);
    final data = json['data'];
    if (data is! Map) {
      throw DioException.badResponse(
        statusCode: 500,
        requestOptions: RequestOptions(path: '/products/$productId/options'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/products/$productId/options'),
          statusCode: 500,
          data: payload,
        ),
      );
    }
    return ProductOptionsResponse.fromJson(Map<String, dynamic>.from(data));
  }
}
