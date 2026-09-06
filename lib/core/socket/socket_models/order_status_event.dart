import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';

class OrderStatusEvent {
  const OrderStatusEvent({
    required this.orderId,
    required this.status,
    required this.timelineType,
    required this.timestamp,
    this.message,
  });

  final String orderId;
  final OrderStatus status;
  final OrderTimelineType timelineType;
  final String? message;
  final DateTime timestamp;

  factory OrderStatusEvent.fromJson(Map<String, dynamic> json) {
    final timelineType = orderTimelineTypeFromRaw(
      _readString(
        json,
        <String>['timelineType', 'timeline_type', 'status'],
        fallback: OrderTimelineType.PENDING.name,
      ),
    );

    return OrderStatusEvent(
      orderId: _readString(
        json,
        <String>['orderId', 'order_id', 'id'],
      ),
      status: orderStatusFromRaw(
        _readString(
          json,
          <String>['orderStatus', 'order_status', 'status'],
          fallback: orderStatusForTimelineType(timelineType).name,
        ),
      ),
      timelineType: timelineType,
      message: _readNullableString(
        json,
        <String>['message', 'text', 'body'],
      ),
      timestamp: _readDateTime(
            json,
            <String>['timestamp', 'updatedAt', 'updated_at', 'createdAt'],
          ) ??
          DateTime.now(),
    );
  }

  static String _readString(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
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

  static DateTime? _readDateTime(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
      if (value is int) {
        final milliseconds = value > 9999999999 ? value : value * 1000;
        return DateTime.fromMillisecondsSinceEpoch(milliseconds);
      }
    }
    return null;
  }
}
