import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/domain/entities/refund_request_status_entity.dart';

class RefundRequestRemoteDataSource {
  const RefundRequestRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<void> createRequest(Map<String, dynamic> body) async {
    await _apiClient.createRefundRequest(body);
  }

  Future<RefundRequestStatusEntity?> getByOrder(String orderId) async {
    final response = await _apiClient.getRefundRequestByOrder(orderId);
    final payload = response.data;
    final data = payload is Map ? payload['data'] : null;
    if (data is! Map) {
      return null;
    }
    return _parseStatus(Map<String, dynamic>.from(data));
  }

  Future<void> cancelRequest(String requestId) async {
    await _apiClient.cancelRefundRequest(requestId);
  }

  RefundRequestStatusEntity _parseStatus(Map<String, dynamic> json) {
    return RefundRequestStatusEntity(
      id: (json['id'] ?? '').toString(),
      itemScope: (json['item_scope'] ?? json['itemScope'] ?? 'ALL').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? 'PENDING').toString(),
      adminNote: _readNullableString(json, <String>['admin_note', 'adminNote']),
      refundAmount: _toDouble(json['refund_amount'] ?? json['refundAmount']),
      refundTo: _readNullableString(json, <String>['refund_to', 'refundTo']),
      createdAt: _readDateTime(json, <String>['created_at', 'createdAt']) ?? DateTime.now(),
    );
  }

  String? _readNullableString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  DateTime? _readDateTime(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }
}
