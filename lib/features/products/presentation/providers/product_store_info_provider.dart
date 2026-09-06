import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/di/providers.dart';

/// Supplying-store information for a product, resolved against the viewer's
/// delivery allocation. Returned by the backend product-detail endpoint under
/// the `store` key. Plain model (no codegen) so it can be added without
/// touching the freezed ProductEntity.
class ProductStoreInfo {
  const ProductStoreInfo({
    required this.shopName,
    required this.isAvailableAtSelectedLocation,
    required this.availabilityReason,
    required this.selectedPincode,
    required this.stockStatus,
    this.shopId,
    this.shopProductId,
  });

  final String? shopId;
  final String? shopProductId;
  final String? shopName;
  final bool isAvailableAtSelectedLocation;
  final String availabilityReason;
  final String? selectedPincode;
  final String stockStatus;

  bool get hasStore => shopName != null && shopName!.trim().isNotEmpty;

  static ProductStoreInfo? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final shopName = json['shopName'] as String?;
    return ProductStoreInfo(
      shopId: json['shopId'] as String?,
      shopProductId: json['shopProductId'] as String?,
      shopName: shopName,
      isAvailableAtSelectedLocation:
          json['isAvailableAtSelectedLocation'] == true,
      availabilityReason:
          (json['availabilityReason'] as String?) ?? 'UNKNOWN',
      selectedPincode: json['selectedPincode'] as String?,
      stockStatus: (json['stockStatus'] as String?) ?? 'unknown',
    );
  }
}

/// Fetches the `store` block from the product detail endpoint. Kept separate
/// from the main product entity so the supplying-store row can render without
/// regenerating the freezed product model. Auto-disposed per product id.
final productStoreInfoProvider =
    FutureProvider.autoDispose.family<ProductStoreInfo?, String>(
  (ref, productId) async {
    final dio = ref.watch(dioClientProvider);
    final response = await dio.get<dynamic>(
      ApiConstants.productById(productId),
    );
    final body = response.data;
    if (body is! Map) return null;
    final data = body['data'];
    if (data is! Map) return null;
    final store = data['store'];
    if (store is! Map) return null;
    return ProductStoreInfo.fromJson(Map<String, dynamic>.from(store));
  },
);
