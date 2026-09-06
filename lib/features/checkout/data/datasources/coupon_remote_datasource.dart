import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/checkout/data/models/coupon_model.dart';

class CouponRemoteDataSource {
  const CouponRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<CouponModel>> getAvailableCoupons() async {
    final response = await _apiClient.getAvailableCoupons();
    final payload = _parsePayload(response.data, ApiConstants.couponsAvailable);
    final data = payload['data'];
    if (data is! List) {
      return const <CouponModel>[];
    }

    return data
        .whereType<Map>()
        .map(
          (item) => CouponModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  Future<CouponModel> validateCoupon({
    required String code,
    required double cartTotal,
  }) async {
    final response = await _apiClient.validateCoupon(
      <String, dynamic>{
        'code': code,
        'cartTotal': cartTotal,
      },
    );
    final payload = _parsePayload(response.data, ApiConstants.couponsValidate);
    final data = payload['data'];
    if (data is! Map) {
      throw DioException.badResponse(
        statusCode: 500,
        requestOptions: RequestOptions(path: ApiConstants.couponsValidate),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: ApiConstants.couponsValidate),
          statusCode: 500,
          data: payload,
        ),
      );
    }

    return CouponModel.fromJson(Map<String, dynamic>.from(data));
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
