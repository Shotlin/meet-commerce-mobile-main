import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/home/data/models/banner_model.dart';
import 'package:bakaloo_flutter_app/features/products/data/models/product_model.dart';

class HomeRemoteDataSource {
  const HomeRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<BannerModel>> getBanners({String? type}) async {
    final response = await _apiClient.getBanners(type: type);
    final data = response.data ?? const <dynamic>[];
    return data
        .whereType<Map>()
        .map(
          (Map item) => BannerModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<List<ProductModel>> getFeaturedProducts({int limit = 12}) async {
    final response = await _apiClient.getFeaturedProducts(limit);
    final data = response.data ?? const <dynamic>[];
    return data
        .whereType<Map>()
        .map(
          (Map item) => ProductModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }
}
