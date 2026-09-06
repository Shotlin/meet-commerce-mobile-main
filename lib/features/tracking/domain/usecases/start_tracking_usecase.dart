import 'package:bakaloo_flutter_app/features/tracking/data/repositories/tracking_repository_impl.dart';

class StartTrackingUseCase {
  const StartTrackingUseCase(this._repository);

  final TrackingRepository _repository;

  void call(String orderId) {
    _repository.startTracking(orderId);
  }
}
