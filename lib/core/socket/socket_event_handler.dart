import 'dart:convert';

import 'package:bakaloo_flutter_app/core/constants/socket_events.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_models/notification_event.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_models/order_status_event.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_models/rider_location_event.dart';

class SocketEventHandler {
  const SocketEventHandler({
    required this.onOrderStatus,
    required this.onRiderLocation,
    required this.onNotification,
  });

  final void Function(OrderStatusEvent event) onOrderStatus;
  final void Function(RiderLocationEvent event) onRiderLocation;
  final void Function(NotificationEvent event) onNotification;

  void route(String eventName, dynamic payload) {
    final json = _toJson(payload);
    if (json == null) {
      return;
    }

    switch (eventName) {
      case SocketEvents.orderStatus:
        onOrderStatus(OrderStatusEvent.fromJson(json));
      case SocketEvents.riderLocationUpdate:
        onRiderLocation(RiderLocationEvent.fromJson(json));
      case SocketEvents.notification:
        onNotification(NotificationEvent.fromJson(json));
    }
  }

  Map<String, dynamic>? _toJson(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    if (payload is String && payload.trim().isNotEmpty) {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }
    return null;
  }
}
