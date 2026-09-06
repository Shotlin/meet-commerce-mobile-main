import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/maps/geo_point.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_models/rider_location_event.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_service.dart';
import 'package:bakaloo_flutter_app/features/tracking/domain/entities/rider_location_entity.dart';
import 'package:bakaloo_flutter_app/features/tracking/presentation/providers/tracking_provider.dart';

part 'rider_location_provider.g.dart';

@riverpod
Stream<GeoPoint> riderLocationForOrder(Ref ref, String orderId) {
  return ref.watch(socketServiceProvider).riderLocationStream.where((event) {
    return event.orderId == orderId;
  }).map((event) {
    return GeoPoint(lat: event.latitude, lng: event.longitude);
  });
}

@riverpod
Stream<RiderLocationEvent> riderLocationEventForOrder(Ref ref, String orderId) {
  return ref.watch(socketServiceProvider).riderLocationStream.where((event) {
    return event.orderId == orderId;
  });
}

@riverpod
Stream<RiderLocationEntity> riderLocationEntityForOrder(
  Ref ref,
  String orderId,
) {
  return ref
      .watch(trackingRepositoryProvider)
      .watchRiderLocations()
      .where((event) {
    return event.orderId == orderId;
  });
}
