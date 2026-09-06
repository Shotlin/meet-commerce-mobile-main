import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/features/checkout/data/datasources/coupon_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/checkout/data/repositories/coupon_repository_impl.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/coupon_entity.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/repositories/coupon_repository.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/usecases/get_coupons.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/usecases/validate_coupon.dart';

part 'coupon_provider.g.dart';

final couponRemoteDataSourceProvider = Provider<CouponRemoteDataSource>((
  Ref ref,
) {
  return CouponRemoteDataSource(ref.watch(apiClientProvider));
});

final couponRepositoryProvider = Provider<CouponRepository>((Ref ref) {
  return CouponRepositoryImpl(
    remoteDataSource: ref.watch(couponRemoteDataSourceProvider),
  );
});

final getCouponsUseCaseProvider = Provider<GetCouponsUseCase>((Ref ref) {
  return GetCouponsUseCase(ref.watch(couponRepositoryProvider));
});

final validateCouponUseCaseProvider =
    Provider<ValidateCouponUseCase>((Ref ref) {
  return ValidateCouponUseCase(ref.watch(couponRepositoryProvider));
});

@riverpod
Future<List<CouponEntity>> availableCoupons(Ref ref) async {
  final result = await ref.read(getCouponsUseCaseProvider).call();
  return result.fold(
    (_) => const <CouponEntity>[],
    (coupons) => coupons,
  );
}
