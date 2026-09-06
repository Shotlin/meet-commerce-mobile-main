import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/features/addresses/data/datasources/address_remote_datasource.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/entities/address_entity.dart';
import 'package:bakaloo_flutter_app/features/addresses/domain/repositories/address_repository.dart';

class AddressRepositoryImpl implements AddressRepository {
  const AddressRepositoryImpl({
    required AddressRemoteDataSource remoteDataSource,
    required String fallbackName,
    required String fallbackPhone,
  })  : _remoteDataSource = remoteDataSource,
        _fallbackName = fallbackName,
        _fallbackPhone = fallbackPhone;

  final AddressRemoteDataSource _remoteDataSource;
  final String _fallbackName;
  final String _fallbackPhone;

  @override
  Future<Either<Failure, List<AddressEntity>>> getAddresses() async {
    try {
      final addresses = await _remoteDataSource.getAddresses();
      return Right(
        addresses
            .map(
              (address) => address.toEntity(
                name: _fallbackName,
                phone: _fallbackPhone,
              ),
            )
            .toList(),
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load addresses right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, AddressEntity>> createAddress(
    AddressUpsertParams params,
  ) async {
    try {
      final address = await _remoteDataSource.createAddress(params.toJson());
      return Right(
        address.toEntity(
          name: _fallbackName,
          phone: _fallbackPhone,
        ),
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to create the address right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, AddressEntity>> updateAddress(
    String id,
    AddressUpsertParams params,
  ) async {
    try {
      final address =
          await _remoteDataSource.updateAddress(id, params.toJson());
      return Right(
        address.toEntity(
          name: _fallbackName,
          phone: _fallbackPhone,
        ),
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to update the address right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> deleteAddress(String id) async {
    try {
      await _remoteDataSource.deleteAddress(id);
      return const Right(null);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to delete the address right now.'),
      );
    }
  }

  @override
  Future<Either<Failure, AddressEntity>> setDefaultAddress(String id) async {
    try {
      final address = await _remoteDataSource.setDefaultAddress(id);
      return Right(
        address.toEntity(
          name: _fallbackName,
          phone: _fallbackPhone,
        ),
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to update the default address.'),
      );
    }
  }

  @override
  Future<Either<Failure, PincodeValidationResult>> validatePincode(
    String pincode,
  ) async {
    try {
      final result = await _remoteDataSource.validatePincode(pincode);
      return Right(
        PincodeValidationResult(
          available: result.available,
          deliveryFee: result.deliveryFee,
          estimatedMin: result.estimatedMin,
          city: result.city,
          area: result.area,
          state: result.state,
        ),
      );
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to validate this pincode right now.'),
      );
    }
  }
}
