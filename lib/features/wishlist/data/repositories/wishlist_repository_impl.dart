import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/wishlist/data/datasources/wishlist_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/wishlist/domain/entities/wishlist_entity.dart';
import 'package:bakaloo_flutter_app/features/wishlist/domain/repositories/wishlist_repository.dart';

class WishlistRepositoryImpl implements WishlistRepository {
  const WishlistRepositoryImpl({
    required WishlistRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final WishlistRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, WishlistEntity>> getWishlist() async {
    try {
      final wishlist = await _remoteDataSource.getWishlist();
      return Right(wishlist);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load wishlist right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, WishlistEntity>> toggleWishlist(
    String productId, {
    required bool isInWishlist,
  }) async {
    try {
      if (isInWishlist) {
        await _remoteDataSource.removeItem(productId);
      } else {
        await _remoteDataSource.addItem(productId);
      }
      final wishlist = await _remoteDataSource.getWishlist();
      return Right(wishlist);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to update wishlist right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, int>> moveToCart() async {
    try {
      final count = await _remoteDataSource.moveToCart();
      return Right(count);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to move wishlist items right now.'),
      );
    }
  }
}
