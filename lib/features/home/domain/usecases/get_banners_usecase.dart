import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/home/domain/entities/banner_entity.dart';
import 'package:bakaloo_flutter_app/features/home/domain/repositories/home_repository.dart';

class GetBannersUseCase {
  const GetBannersUseCase(this._repository);

  final HomeRepository _repository;

  Future<Either<Failure, List<BannerEntity>>> call({String? type}) {
    return _repository.getBanners(type: type);
  }
}
