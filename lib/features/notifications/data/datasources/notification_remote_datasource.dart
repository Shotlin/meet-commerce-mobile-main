import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/notifications/data/models/notification_model.dart';

class NotificationRemoteDataSource {
  const NotificationRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<NotificationsPageModel> getNotifications({
    required int page,
    required int limit,
  }) async {
    final response = await _apiClient.getNotifications(page, limit);
    final payload = _parsePayload(response.data, ApiConstants.notifications);
    return NotificationsPageModel.fromPayload(
      payload,
      page: page,
      limit: limit,
    );
  }

  Future<void> markRead(String notificationId) async {
    try {
      await _apiClient.markNotificationRead(notificationId);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 404 || status == 405) {
        await _apiClient.markNotificationReadPatch(notificationId);
        return;
      }
      rethrow;
    }
  }

  Future<void> markAllRead() async {
    try {
      await _apiClient.markAllNotificationsRead();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 404 || status == 405) {
        await _apiClient.markAllNotificationsReadPatch();
        return;
      }
      rethrow;
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    await _apiClient.deleteNotification(notificationId);
  }

  Future<void> markCampaignOpened(String campaignId) async {
    await _apiClient.markCampaignOpened(campaignId);
  }

  Future<void> registerFcmToken({
    required String token,
    required String platform,
  }) async {
    await _apiClient.registerNotificationToken(
      <String, dynamic>{
        'token': token,
        'platform': platform,
      },
    );
  }

  Future<NotificationPreferenceModel> getPreferences() async {
    final response = await _apiClient.getNotificationPreferences();
    final payload = _parsePayload(
      response.data,
      ApiConstants.notificationPreferences,
    );
    final data = payload['data'];
    if (data is Map) {
      return NotificationPreferenceModel.fromJson(
        Map<String, dynamic>.from(data),
      );
    }
    throw _badResponse(ApiConstants.notificationPreferences, payload);
  }

  Future<NotificationPreferenceModel> updatePreferences(
    NotificationPreferenceModel preferences,
  ) async {
    final response = await _apiClient.updateNotificationPreferences(
      preferences.toJson(),
    );
    final payload = _parsePayload(
      response.data,
      ApiConstants.notificationPreferences,
    );
    final data = payload['data'];
    if (data is Map) {
      return NotificationPreferenceModel.fromJson(
        Map<String, dynamic>.from(data),
      );
    }
    throw _badResponse(ApiConstants.notificationPreferences, payload);
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
