import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/addresses/data/models/address_model.dart';

class PincodeValidationModel {
  const PincodeValidationModel({
    required this.available,
    required this.deliveryFee,
    required this.estimatedMin,
    this.city,
    this.area,
    this.state,
  });

  final bool available;
  final double deliveryFee;
  final int estimatedMin;

  // Admin-curated override from the dashboard's Pincode Mapping table —
  // only present when an active mapping matches this pincode. Present so
  // the address form can trust it over the public reverse-geocoder.
  final String? city;
  final String? area;
  final String? state;
}

class AddressRemoteDataSource {
  const AddressRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AddressModel>> getAddresses() async {
    final response = await _apiClient.getAddresses();
    final payload = _parsePayload(response.data, ApiConstants.addresses);
    final data = payload['data'];

    if (data is! List) {
      return const <AddressModel>[];
    }

    return data
        .whereType<Map>()
        .map(
          (item) => AddressModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<AddressModel> createAddress(Map<String, dynamic> body) async {
    final response = await _apiClient.createAddress(body);
    return _parseAddress(response.data, ApiConstants.addresses);
  }

  Future<AddressModel> updateAddress(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await _apiClient.updateAddress(id, body);
    return _parseAddress(response.data, ApiConstants.addressById(id));
  }

  Future<void> deleteAddress(String id) async {
    await _apiClient.deleteAddress(id);
  }

  Future<AddressModel> setDefaultAddress(String id) async {
    final response = await _apiClient.setDefaultAddress(id);
    return _parseAddress(response.data, ApiConstants.addressDefault(id));
  }

  Future<PincodeValidationModel> validatePincode(String pincode) async {
    final response = await _apiClient.validatePincode(
      <String, dynamic>{'pincode': pincode},
    );
    final payload = _parsePayload(response.data, ApiConstants.validatePincode);
    final data = payload['data'];

    if (data is! Map) {
      throw DioException.badResponse(
        statusCode: 500,
        requestOptions: RequestOptions(path: ApiConstants.validatePincode),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: ApiConstants.validatePincode),
          statusCode: 500,
          data: payload,
        ),
      );
    }

    final json = Map<String, dynamic>.from(data);
    return PincodeValidationModel(
      available: json['available'] as bool? ?? false,
      deliveryFee: _toDouble(json['deliveryFee']),
      estimatedMin: json['estimatedMin'] as int? ?? 0,
      city: (json['city'] as String?)?.trim(),
      area: (json['area'] as String?)?.trim(),
      state: (json['state'] as String?)?.trim(),
    );
  }

  AddressModel _parseAddress(dynamic raw, String path) {
    final payload = _parsePayload(raw, path);
    final data = payload['data'];
    if (data is! Map) {
      throw DioException.badResponse(
        statusCode: 500,
        requestOptions: RequestOptions(path: path),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: path),
          statusCode: 500,
          data: payload,
        ),
      );
    }

    return AddressModel.fromJson(Map<String, dynamic>.from(data));
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
