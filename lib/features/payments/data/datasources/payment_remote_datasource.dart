import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/payments/data/models/payment_history_model.dart';
import 'package:bakaloo_flutter_app/features/payments/data/models/razorpay_order_model.dart';
import 'package:bakaloo_flutter_app/features/payments/domain/repositories/payment_repository.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

class PaymentRemoteDataSource {
  const PaymentRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<RazorpayOrderModel> createPaymentOrder(String orderId) async {
    final response = await _apiClient.createPaymentOrder(
      <String, dynamic>{'orderId': orderId},
    );
    final data = _parseDataMap(response.data, ApiConstants.paymentsCreateOrder);
    return RazorpayOrderModel.fromJson(data, orderId: orderId);
  }

  Future<PaymentHistoryModel> verifyPayment(
    PaymentVerificationParams params,
  ) async {
    final response = await _apiClient.verifyPayment(params.toJson());
    final data = _parseDataMap(response.data, ApiConstants.paymentsVerify);
    return PaymentHistoryModel.fromJson(data);
  }

  Future<PaymentHistoryPageModel> getHistory({
    required int page,
    required int limit,
  }) async {
    final response = await _apiClient.getPaymentHistory(page, limit);
    final payload = _parsePayload(response.data, ApiConstants.paymentsHistory);
    final items = payload['data'];
    final paginationRaw = payload['pagination'];

    final payments = items is List
        ? items
            .whereType<Map>()
            .map(
              (item) =>
                  PaymentHistoryModel.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false)
        : const <PaymentHistoryModel>[];

    final pagination = paginationRaw is Map
        ? PaginationEntity.fromJson(Map<String, dynamic>.from(paginationRaw))
        : PaginationEntity(
            page: page,
            limit: limit,
            total: payments.length,
            totalPages: payments.isEmpty ? 0 : 1,
          );

    return PaymentHistoryPageModel(
      payments: payments,
      pagination: pagination,
    );
  }

  Future<RazorpayOrderModel> createWalletTopup(
    WalletTopupParams params,
  ) async {
    final response = await _apiClient.createWalletTopup(params.toJson());
    final data = _parseDataMap(response.data, ApiConstants.walletTopup);
    final razorpayOrderId =
        _readString(data, <String>['razorpayOrderId', 'orderId']);
    return RazorpayOrderModel.fromJson(
      data,
      orderId: razorpayOrderId,
    );
  }

  Future<double> verifyWalletTopup(
    WalletTopupVerificationParams params,
  ) async {
    final response = await _apiClient.verifyWalletTopup(params.toJson());
    return _parseWalletBalance(response.data, ApiConstants.walletTopupVerify);
  }

  /// Current authoritative status of a Razorpay order — polled after the
  /// checkout SDK reports an ambiguous result (any error that isn't a
  /// genuine user cancellation) instead of assuming failure and cancelling
  /// blind. Never throws on a 404 (payment record not found yet) — that's
  /// treated as "still pending" by the caller's poll loop, same as a
  /// network hiccup, since retrying is always safe here.
  Future<
      ({
        String status,
        String? errorCode,
        String? errorDescription,
        String? errorReason,
      })> getPaymentStatus(String razorpayOrderId) async {
    final response = await _apiClient.getPaymentStatus(razorpayOrderId);
    final data = _parseDataMap(response.data, 'payments/status');
    return (
      status: _readString(data, <String>['status']),
      errorCode: _readNullableString(data, 'errorCode'),
      errorDescription: _readNullableString(data, 'errorDescription'),
      errorReason: _readNullableString(data, 'errorReason'),
    );
  }

  Future<double> getWalletBalance() async {
    final response = await _apiClient.getWallet();
    return _parseWalletBalance(response.data, ApiConstants.wallet);
  }

  Future<double> payFromWallet(String orderId) async {
    final response = await _apiClient.payFromWallet(
      <String, dynamic>{'orderId': orderId},
    );
    return _parseWalletBalance(response.data, ApiConstants.walletPay);
  }

  double _parseWalletBalance(dynamic raw, String path) {
    final payload = _parsePayload(raw, path);
    final data = payload['data'];
    if (data is! Map) {
      throw _badResponse(path, payload);
    }

    final json = Map<String, dynamic>.from(data);
    final wallet = json['wallet'];
    if (wallet is! Map) {
      if (json.containsKey('balance')) {
        return _toDouble(json['balance']);
      }
      throw _badResponse(path, payload);
    }

    final walletJson = Map<String, dynamic>.from(wallet);
    return _toDouble(walletJson['balance']);
  }

  Map<String, dynamic> _parseDataMap(dynamic raw, String path) {
    final payload = _parsePayload(raw, path);
    final data = payload['data'];
    if (data is! Map) {
      throw _badResponse(path, payload);
    }
    return Map<String, dynamic>.from(data);
  }

  Map<String, dynamic> _parsePayload(dynamic raw, String path) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    throw _badResponse(path, raw);
  }

  DioException _badResponse(String path, dynamic raw) {
    return DioException.badResponse(
      statusCode: 500,
      requestOptions: RequestOptions(path: path),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: path),
        statusCode: 500,
        data: raw,
      ),
    );
  }

  double _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  String? _readNullableString(Map<String, dynamic> json, String key) {
    final value = json[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }
}
