import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/purchase_limits/domain/entities/purchase_limit_status_entity.dart';

abstract class PurchaseLimitsRepository {
  Future<Either<Failure, List<PurchaseLimitStatusEntity>>> getStatus(
    List<String> productIds,
  );
}
