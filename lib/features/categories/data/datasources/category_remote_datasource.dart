import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/categories/domain/entities/category_entity.dart';
import 'package:bakaloo_flutter_app/features/products/data/models/product_model.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

class CategoryRemotePage {
  const CategoryRemotePage({
    required this.items,
    required this.pagination,
  });

  final List<ProductModel> items;
  final PaginationEntity pagination;
}

class CategoryRemoteDataSource {
  const CategoryRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<CategoryEntity>> getCategories() async {
    final response = await _apiClient.getCategories();
    final data = response.data ?? const <dynamic>[];
    return data
        .whereType<Map>()
        .map(
          (Map item) => _mapCategory(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<CategoryRemotePage> getCategoryProducts({
    required String categoryId,
    required int page,
    required int limit,
    bool groupOptions = true,
  }) async {
    final response = await _apiClient.getCategoryProducts(
      categoryId,
      page,
      limit,
      groupOptions: groupOptions ? true : null,
    );

    final payload = Map<String, dynamic>.from(response.data as Map);
    final items = (payload['data'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (Map item) => ProductModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
    final paginationJson = payload['pagination'];
    final pagination = paginationJson is Map
        ? PaginationEntity.fromJson(Map<String, dynamic>.from(paginationJson))
        : PaginationEntity(
            page: page,
            limit: limit,
            total: items.length,
            totalPages: items.isEmpty ? 0 : 1,
          );

    return CategoryRemotePage(items: items, pagination: pagination);
  }

  CategoryEntity _mapCategory(Map<String, dynamic> json) {
    return CategoryEntity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      imageUrl: ApiConstants.resolveMediaUrl(json['image_url']?.toString()),
      parentId: json['parent_id']?.toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      productCount: (json['product_count'] as num?)?.toInt() ?? 0,
      categoryType: json['category_type']?.toString() ?? 'STANDARD',
    );
  }
}
