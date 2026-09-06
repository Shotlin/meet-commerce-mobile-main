import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/auth/data/models/auth_response_model.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<void> sendOtp({required String phone}) async {
    await _apiClient.sendOtp(<String, dynamic>{'phone': phone});
  }

  Future<AuthResponseModel> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final response = await _apiClient.verifyOtp(
      <String, dynamic>{
        'phone': phone,
        'otp': otp,
      },
    );

    final data = response.data;
    if (data == null) {
      throw _missingDataException(
        path: ApiConstants.verifyOtp,
        message: 'Authentication response is missing user session data.',
      );
    }

    return data;
  }

  Future<TokenModel> refreshToken({required String refreshToken}) async {
    final response = await _apiClient.refreshToken(
      <String, dynamic>{'refreshToken': refreshToken},
    );

    final data = response.data;
    if (data == null) {
      throw _missingDataException(
        path: ApiConstants.refreshToken,
        message: 'Refresh token response is missing token data.',
      );
    }

    return data;
  }

  Future<void> logout() async {
    await _apiClient.logout();
  }

  Future<void> deleteAccount() async {
    await _apiClient.deleteAccount();
  }

  DioException _missingDataException({
    required String path,
    required String message,
  }) {
    final requestOptions = RequestOptions(path: path);
    return DioException(
      requestOptions: requestOptions,
      response: Response<dynamic>(
        requestOptions: requestOptions,
        statusCode: 500,
      ),
      type: DioExceptionType.badResponse,
      error: ServerFailure(message: message),
      message: message,
    );
  }
}
