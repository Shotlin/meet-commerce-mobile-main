import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/checkout/data/datasources/coupon_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/coupon_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/repositories/coupon_repository.dart';

class CouponRepositoryImpl implements CouponRepository {
  const CouponRepositoryImpl({
    required CouponRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final CouponRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, List<CouponEntity>>> getCoupons() async {
    try {
      final coupons = await _remoteDataSource.getAvailableCoupons();
      return Right(
        coupons.map((coupon) => coupon.toEntity()).toList(growable: false),
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load coupons right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, CouponEntity>> validateCoupon({
    required String code,
    required double cartTotal,
  }) async {
    try {
      final coupon = await _remoteDataSource.validateCoupon(
        code: code,
        cartTotal: cartTotal,
      );
      return Right(coupon.toEntity());
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to validate this coupon right now.'),
      );
    }
  }
}
