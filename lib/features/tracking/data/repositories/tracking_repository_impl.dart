import 'package:bakaloo_flutter_app/core/socket/socket_models/notification_event.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_models/order_status_event.dart';
import 'package:bakaloo_flutter_app/features/tracking/data/tracking_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/tracking/domain/entities/rider_location_entity.dart';

abstract class TrackingRepository {
  void startTracking(String orderId);

  void stopTracking(String orderId);

  Stream<OrderStatusEvent> watchOrderStatus();

  Stream<NotificationEvent> watchNotifications();

  Stream<RiderLocationEntity> watchRiderLocations();
}

class TrackingRepositoryImpl implements TrackingRepository {
  const TrackingRepositoryImpl({
    required TrackingRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final TrackingRemoteDataSource _remoteDataSource;

  @override
  void startTracking(String orderId) {
    _remoteDataSource.startTracking(orderId);
  }

  @override
  void stopTracking(String orderId) {
    _remoteDataSource.stopTracking(orderId);
  }

  @override
  Stream<OrderStatusEvent> watchOrderStatus() {
    return _remoteDataSource.orderStatusStream;
  }

  @override
  Stream<NotificationEvent> watchNotifications() {
    return _remoteDataSource.notificationStream;
  }

  @override
  Stream<RiderLocationEntity> watchRiderLocations() {
    return _remoteDataSource.riderLocationStream.map((event) {
      return RiderLocationEntity(
        orderId: event.orderId,
        latitude: event.latitude,
        longitude: event.longitude,
        bearing: event.heading,
        speed: event.speed,
        updatedAt: event.timestamp ?? DateTime.now(),
      );
    });
  }
}
