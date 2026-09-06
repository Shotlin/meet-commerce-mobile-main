import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';

class OrderTimelineModel {
  const OrderTimelineModel({
    required this.type,
    required this.status,
    required this.timestamp,
    this.message,
  });

  final OrderTimelineType type;
  final OrderStatus status;
  final DateTime timestamp;
  final String? message;

  factory OrderTimelineModel.fromJson(Map<String, dynamic> json) {
    final type = orderTimelineTypeFromRaw(
      _readString(json, <String>['type', 'timelineType', 'status']),
    );

    return OrderTimelineModel(
      type: type,
      status: orderStatusFromRaw(
        _readStringWithFallback(
          json,
          <String>['status', 'orderStatus'],
          fallback: orderStatusForTimelineType(type).name,
        ),
      ),
      timestamp: _readDateTime(
            json,
            <String>['timestamp', 'createdAt', 'created_at', 'time'],
          ) ??
          DateTime.now(),
      message: _readNullableString(json, <String>['message', 'label']),
    );
  }

  OrderTimelineEntity toEntity() {
    return OrderTimelineEntity(
      type: type,
      status: status,
      timestamp: timestamp,
      message: message,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type.name,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'message': message,
    };
  }

  static String _readString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    return _readStringWithFallback(json, keys, fallback: '');
  }

  static String _readStringWithFallback(
    Map<String, dynamic> json,
    List<String> keys, {
    required String fallback,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return fallback;
  }

  static String? _readNullableString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static DateTime? _readDateTime(Map<String, dynamic> json, List<String> keys) {
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
}
