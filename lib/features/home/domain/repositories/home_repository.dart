import 'package:dartz/dartz.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/home/domain/entities/banner_entity.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';

abstract class HomeRepository {
  Future<Either<Failure, List<BannerEntity>>> getBanners({String? type});

  Future<Either<Failure, List<ProductEntity>>> getFeaturedProducts({
    int limit = 12,
  });
}
