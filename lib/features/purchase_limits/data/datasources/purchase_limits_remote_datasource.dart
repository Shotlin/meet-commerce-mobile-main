import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/data/models/purchase_limit_status_model.dart';

class PurchaseLimitsRemoteDataSource {
  const PurchaseLimitsRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  /// Calls `GET /purchase-limits/my-status?productIds=a,b,c`. Only
  /// products the backend currently restricts for this customer come back
  /// — a requested id with no matching entry in the result is completely
  /// unrestricted (the safe default), not an error.
  Future<List<PurchaseLimitStatusModel>> getStatus(
    List<String> productIds,
  ) async {
    if (productIds.isEmpty) {
      return const <PurchaseLimitStatusModel>[];
    }

    final response = await _apiClient.getPurchaseLimitsStatus(
      productIds.join(','),
    );

    final payload = response.data;
    if (payload is! Map) {
      return const <PurchaseLimitStatusModel>[];
    }

    final data = Map<String, dynamic>.from(payload)['data'];
    if (data is! Map) {
      return const <PurchaseLimitStatusModel>[];
    }

    final items = Map<String, dynamic>.from(data)['items'];
    if (items is! List) {
      return const <PurchaseLimitStatusModel>[];
    }

    return items
        .whereType<Map>()
        .map(
          (Map item) => PurchaseLimitStatusModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }
}
