import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/products/data/models/product_model.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

class SearchRemoteResult {
  const SearchRemoteResult({
    required this.products,
    required this.suggestions,
    required this.pagination,
  });

  final List<ProductModel> products;
  final List<ProductModel> suggestions;
  final PaginationEntity pagination;
}

class SearchRemoteDataSource {
  const SearchRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<SearchRemoteResult> searchProducts({
    required String query,
    required int page,
    required int limit,
  }) async {
    final response = await _apiClient.searchProducts(query, page, limit);
    final payload = response.data;

    if (payload is! Map) {
      throw DioException.badResponse(
        statusCode: 500,
        requestOptions: RequestOptions(path: ApiConstants.productsSearch),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: ApiConstants.productsSearch),
          statusCode: 500,
          data: payload,
        ),
      );
    }

    final json = Map<String, dynamic>.from(payload);
    final dataPayload = json['data'];

    final products = dataPayload is Map
        ? _parseList(
            dataPayload['products'] ??
                dataPayload['items'] ??
                dataPayload['data'],
          )
        : _parseList(dataPayload);

    final suggestions = dataPayload is Map
        ? _parseList(dataPayload['suggestions'] ?? json['suggestions'])
        : _parseList(json['suggestions']);

    final paginationPayload = dataPayload is Map
        ? dataPayload['pagination'] ?? json['pagination']
        : json['pagination'];
    final pagination = paginationPayload is Map
        ? PaginationEntity.fromJson(
            Map<String, dynamic>.from(paginationPayload),
          )
        : PaginationEntity(
            page: page,
            limit: limit,
            total: products.length,
            totalPages: products.isEmpty ? 0 : 1,
          );

    return SearchRemoteResult(
      products: products,
      suggestions: suggestions,
      pagination: pagination,
    );
  }

  List<ProductModel> _parseList(dynamic rawList) {
    if (rawList is! List) {
      return const <ProductModel>[];
    }

    return rawList
        .whereType<Map>()
        .map(
          (item) => ProductModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }
}
