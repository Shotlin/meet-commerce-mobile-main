import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/cart/data/datasources/cart_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/repositories/cart_repository.dart';

class CartRepositoryImpl implements CartRepository {
  const CartRepositoryImpl({
    required CartRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final CartRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, CartEntity>> getCart() async {
    try {
      final cart = await _remoteDataSource.getCart();
      return Right(cart.toEntity());
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to fetch your cart right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, CartEntity>> addToCart({
    required String productId,
    required int quantity,
    String? shopProductId,
  }) async {
    try {
      final cart = await _remoteDataSource.addItem(
        productId: productId,
        quantity: quantity,
        shopProductId: shopProductId,
      );
      return Right(cart.toEntity());
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to add this item right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, CartEntity>> updateItem({
    required String productId,
    required int quantity,
    String? shopProductId,
  }) async {
    try {
      final cart = await _remoteDataSource.updateItem(
        productId: productId,
        quantity: quantity,
        shopProductId: shopProductId,
      );
      return Right(cart.toEntity());
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to update this cart item right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, CartEntity>> removeItem(
    String productId, {
    String? shopProductId,
  }) async {
    try {
      final cart = await _remoteDataSource.removeItem(
        productId,
        shopProductId: shopProductId,
      );
      return Right(cart.toEntity());
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to remove this item right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> clearCart() async {
    try {
      await _remoteDataSource.clearCart();
      return const Right(null);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to clear your cart right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, CartValidationResult>> validateCart() async {
    try {
      final result = await _remoteDataSource.validateCart();
      return Right(
        CartValidationResult(
          valid: result.valid,
          cart: result.cart.toEntity(),
          warnings: result.warnings,
        ),
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to validate your cart right now.'),
      );
    }
  }
}
