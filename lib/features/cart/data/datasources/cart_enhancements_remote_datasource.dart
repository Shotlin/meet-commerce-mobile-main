import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/bill_summary_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/payment_offer_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/tip_preset_entity.dart';
import 'package:bakaloo_flutter_app/features/products/data/models/product_model.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';

class CartEnhancementsRemoteDataSource {
  const CartEnhancementsRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<Either<Failure, BillSummaryEntity>> getCartSummary({
    bool quickDeliverySelected = false,
    String? addressId,
  }) async {
    try {
      final response = await _apiClient.getCartSummary(
        quickDeliverySelected: quickDeliverySelected,
        addressId: addressId,
      );
      final data = response.data;
      if (data == null) {
        return const Left(
          UnknownFailure(
            message: 'Unable to load your bill summary right now.',
          ),
        );
      }
      return Right(data);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load your bill summary right now.'),
      );
    }
  }

  Future<Either<Failure, void>> updateTip(double amount) async {
    try {
      await _apiClient.updateCartTip(<String, dynamic>{'amount': amount});
      return const Right(null);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to update your tip right now.'),
      );
    }
  }

  Future<Either<Failure, void>> updateDeliveryInstructions(
    String instructions,
  ) async {
    try {
      await _apiClient.updateDeliveryInstructions(
        <String, dynamic>{'instructions': instructions},
      );
      return const Right(null);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(
          message: 'Unable to update delivery instructions right now.',
        ),
      );
    }
  }

  Future<Either<Failure, List<TipPresetEntity>>> getTipPresets() async {
    try {
      final response = await _apiClient.getTipPresets();
      return Right(response.data ?? const <TipPresetEntity>[]);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load tip presets right now.'),
      );
    }
  }

  Future<Either<Failure, List<PaymentOfferEntity>>> getPaymentOffers(
    double cartTotal,
  ) async {
    try {
      final response = await _apiClient.getPaymentOffers(cartTotal);
      return Right(response.data ?? const <PaymentOfferEntity>[]);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(message: 'Unable to load payment offers right now.'),
      );
    }
  }

  Future<Either<Failure, List<Map<String, dynamic>>>>
      getPriceDropProducts() async {
    try {
      final response = await _apiClient.getPriceDropProducts();
      final rawProducts = _extractListResponse(
        response.data,
        fallbackMessage: 'Unable to load price drop products right now.',
      );
      final products = rawProducts
          .whereType<Map<Object?, Object?>>()
          .map(
            (item) => item.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          )
          .toList(growable: false);
      return Right(products);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(
          message: 'Unable to load price drop products right now.',
        ),
      );
    }
  }

  Future<Either<Failure, List<Map<String, dynamic>>>>
      getLastMinuteProducts() async {
    try {
      final response = await _apiClient.getLastMinuteProducts();
      final rawProducts = _extractListResponse(
        response.data,
        fallbackMessage: 'Unable to load last-minute products right now.',
      );
      final products = rawProducts
          .whereType<Map<Object?, Object?>>()
          .map(
            (item) => item.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          )
          .toList(growable: false);
      return Right(products);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(
          message: 'Unable to load last-minute products right now.',
        ),
      );
    }
  }

  Future<Either<Failure, List<ProductEntity>>> getCartQuickAdd({
    int limit = 12,
  }) async {
    try {
      final response = await _apiClient.getCartQuickAdd(limit);
      final rawProducts = _extractListResponse(
        response.data,
        fallbackMessage: 'Unable to load quick add suggestions right now.',
      );
      final products = rawProducts
          .whereType<Map>()
          .map(
            (item) => ProductModel.fromJson(
              Map<String, dynamic>.from(item),
            ).toEntity(),
          )
          .toList(growable: false);
      return Right(products);
    } on DioException catch (error) {
      return Left(handleDioError(error));
    } catch (_) {
      return const Left(
        UnknownFailure(
          message: 'Unable to load quick add suggestions right now.',
        ),
      );
    }
  }

  List<dynamic> _extractListResponse(
    dynamic raw, {
    required String fallbackMessage,
  }) {
    if (raw is Map<Object?, Object?>) {
      final data = raw['data'];
      if (data is List<dynamic>) {
        return data;
      }
    }

    throw DioException.badResponse(
      statusCode: 500,
      requestOptions: RequestOptions(path: ''),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 500,
        data: raw,
        statusMessage: fallbackMessage,
      ),
    );
  }
}
