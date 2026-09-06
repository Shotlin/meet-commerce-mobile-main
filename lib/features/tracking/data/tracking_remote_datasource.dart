import 'package:bakaloo_flutter_app/core/socket/socket_models/notification_event.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_models/order_status_event.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_models/rider_location_event.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_service.dart';

class TrackingRemoteDataSource {
  const TrackingRemoteDataSource(this._socketService);

  final SocketService _socketService;

  void startTracking(String orderId) {
    _socketService.startTracking(orderId);
  }

  void stopTracking(String orderId) {
    _socketService.stopTracking(orderId);
  }

  Stream<OrderStatusEvent> get orderStatusStream =>
      _socketService.orderStatusStream;

  Stream<RiderLocationEvent> get riderLocationStream =>
      _socketService.riderLocationStream;

  Stream<NotificationEvent> get notificationStream =>
      _socketService.notificationStream;
}
