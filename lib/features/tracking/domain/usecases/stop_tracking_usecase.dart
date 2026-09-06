import 'package:bakaloo_flutter_app/features/tracking/data/repositories/tracking_repository_impl.dart';

class StopTrackingUseCase {
  const StopTrackingUseCase(this._repository);

  final TrackingRepository _repository;

  void call(String orderId) {
    _repository.stopTracking(orderId);
  }
}
