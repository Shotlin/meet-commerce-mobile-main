import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/socket/socket_models/notification_event.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_service.dart';
import 'package:bakaloo_flutter_app/features/tracking/data/repositories/tracking_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/tracking/data/tracking_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/tracking/domain/entities/rider_location_entity.dart';
import 'package:bakaloo_flutter_app/features/tracking/domain/usecases/start_tracking_usecase.dart';
import 'package:bakaloo_flutter_app/features/tracking/domain/usecases/stop_tracking_usecase.dart';

part 'tracking_provider.g.dart';

final trackingRemoteDataSourceProvider = Provider<TrackingRemoteDataSource>((
  Ref ref,
) {
  return TrackingRemoteDataSource(ref.watch(socketServiceProvider));
});

final trackingRepositoryProvider = Provider<TrackingRepository>((Ref ref) {
  return TrackingRepositoryImpl(
    remoteDataSource: ref.watch(trackingRemoteDataSourceProvider),
  );
});

final startTrackingUseCaseProvider = Provider<StartTrackingUseCase>((Ref ref) {
  return StartTrackingUseCase(ref.watch(trackingRepositoryProvider));
});

final stopTrackingUseCaseProvider = Provider<StopTrackingUseCase>((Ref ref) {
  return StopTrackingUseCase(ref.watch(trackingRepositoryProvider));
});

@riverpod
Stream<RiderLocationEntity> riderLocationStream(Ref ref) {
  return ref.watch(trackingRepositoryProvider).watchRiderLocations();
}

@riverpod
Stream<NotificationEvent> notificationStream(Ref ref) {
  return ref.watch(trackingRepositoryProvider).watchNotifications();
}

@Riverpod(keepAlive: true)
int unreadNotificationCount(Ref ref) {
  return 0;
}
