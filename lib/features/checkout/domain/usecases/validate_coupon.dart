import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/coupon_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/repositories/coupon_repository.dart';

class ValidateCouponUseCase {
  const ValidateCouponUseCase(this._repository);

  final CouponRepository _repository;

  Future<Either<Failure, CouponEntity>> call({
    required String code,
    required double cartTotal,
  }) {
    return _repository.validateCoupon(
      code: code,
      cartTotal: cartTotal,
    );
  }
}
