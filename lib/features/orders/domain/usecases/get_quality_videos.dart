import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_quality_videos_result.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/repositories/order_repository.dart';

class GetOrderQualityVideosUseCase {
  const GetOrderQualityVideosUseCase(this._repository);

  final OrderRepository _repository;

  Future<Either<Failure, OrderQualityVideosResult>> call(
    String orderId,
  ) {
    return _repository.getQualityVideos(orderId);
  }
}
