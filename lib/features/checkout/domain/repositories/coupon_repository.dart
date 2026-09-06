import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/coupon_entity.dart';

abstract class CouponRepository {
  Future<Either<Failure, List<CouponEntity>>> getCoupons();

  Future<Either<Failure, CouponEntity>> validateCoupon({
    required String code,
    required double cartTotal,
  });
}
