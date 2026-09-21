import 'dart:io';

import 'package:dio/dio.dart';
import 'package:retrofit/dio.dart' as retrofit;

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/profile/data/models/user_profile_model.dart';
import 'package:bakaloo_flutter_app/features/profile/data/models/user_stats_model.dart';
import 'package:bakaloo_flutter_app/features/profile/domain/repositories/profile_repository.dart';

class UserRemoteDataSource {
  const UserRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<UserProfileModel> getProfile() async {
    final response = await _apiClient.getMe();
    final payload = _parsePayload(response.data, ApiConstants.me);
    final data = _extractData(payload, ApiConstants.me);
    return UserProfileModel.fromJson(data);
  }

  Future<UserProfileModel> updateProfile(UpdateProfileParams params) async {
    final response = await _apiClient.updateMe(params.toJson());
    final payload = _parsePayload(response.data, ApiConstants.me);
    final data = _extractData(payload, ApiConstants.me);
    return UserProfileModel.fromJson(data);
  }

  Future<String> uploadAvatar(File imageFile) async {
    final fileName = imageFile.path.split(Platform.pathSeparator).last;
    final avatarFile = await MultipartFile.fromFile(
      imageFile.path,
      filename: fileName.isEmpty ? 'avatar.jpg' : fileName,
    );
    final response = await _uploadAvatarWithFallback(avatarFile);
    final payload = _parsePayload(response.data, ApiConstants.meAvatar);
    final data = _extractData(payload, ApiConstants.meAvatar);
    final avatarUrl = data['avatar_url'] ?? data['avatarUrl'];

    if (avatarUrl is! String || avatarUrl.trim().isEmpty) {
      throw _badResponse(ApiConstants.meAvatar, payload);
    }
    return avatarUrl.trim();
  }

  Future<retrofit.HttpResponse<dynamic>> _uploadAvatarWithFallback(
    MultipartFile avatarFile,
  ) async {
    try {
      return await _apiClient.uploadMeAvatarPost(avatarFile);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 404 || status == 405) {
        return _apiClient.uploadMeAvatar(avatarFile);
      }
      rethrow;
    }
  }

  Future<UserStatsModel> getStats() async {
    final response = await _apiClient.getMeStats();
    final payload = _parsePayload(response.data, ApiConstants.meStats);
    final data = _extractData(payload, ApiConstants.meStats);
    return UserStatsModel.fromJson(data);
  }

  Map<String, dynamic> _extractData(Map<String, dynamic> payload, String path) {
    final data = payload['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw _badResponse(path, payload);
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
}
