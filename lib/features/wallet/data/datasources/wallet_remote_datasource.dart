import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/payments/data/models/razorpay_order_model.dart';
import 'package:bakaloo_flutter_app/features/wallet/data/models/transaction_model.dart';
import 'package:bakaloo_flutter_app/features/wallet/data/models/wallet_model.dart';
import 'package:bakaloo_flutter_app/features/wallet/data/models/wallet_recipient_model.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/entities/transaction_entity.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:bakaloo_flutter_app/shared/entities/pagination_entity.dart';

class WalletTransactionsPageModel {
  const WalletTransactionsPageModel({
    required this.transactions,
    required this.pagination,
  });

  final List<TransactionModel> transactions;
  final PaginationEntity pagination;
}

class WalletRemoteDataSource {
  const WalletRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<WalletModel> getWallet() async {
    final response = await _apiClient.getWallet();
    final payload = _parsePayload(response.data, ApiConstants.wallet);
    final data = payload['data'];

    if (data is Map) {
      return WalletModel.fromJson(Map<String, dynamic>.from(data));
    }

    throw _badResponse(ApiConstants.wallet, payload);
  }

  Future<WalletTransactionsPageModel> getTransactions({
    required int page,
    required int limit,
    WalletTransactionType? type,
  }) async {
    final response = await _apiClient.getWalletTransactions(
      page,
      limit,
      type?.name,
    );
    final payload =
        _parsePayload(response.data, ApiConstants.walletTransactions);
    final listData = payload['data'];
    final paginationData = payload['pagination'];

    final transactions = listData is List
        ? listData.whereType<Map>().map((item) {
            return TransactionModel.fromJson(Map<String, dynamic>.from(item));
          }).toList(growable: false)
        : const <TransactionModel>[];

    final pagination = paginationData is Map
        ? PaginationEntity.fromJson(Map<String, dynamic>.from(paginationData))
        : PaginationEntity(
            page: page,
            limit: limit,
            total: transactions.length,
            totalPages: transactions.isEmpty ? 0 : 1,
          );

    return WalletTransactionsPageModel(
      transactions: transactions,
      pagination: pagination,
    );
  }

  Future<RazorpayOrderModel> topup(double amount) async {
    final response = await _apiClient.createWalletTopup(<String, dynamic>{
      'amount': amount,
    });
    final payload = _parsePayload(response.data, ApiConstants.walletTopup);
    final data = payload['data'];

    if (data is! Map) {
      throw _badResponse(ApiConstants.walletTopup, payload);
    }

    final json = Map<String, dynamic>.from(data);
    final orderId = _readString(json, <String>['razorpayOrderId', 'orderId']);
    return RazorpayOrderModel.fromJson(json, orderId: orderId);
  }

  Future<WalletModel> topupVerify(WalletTopupVerifyParams params) async {
    final response = await _apiClient.verifyWalletTopup(params.toJson());
    return _parseWalletFromMutation(
      response.data,
      ApiConstants.walletTopupVerify,
    );
  }

  Future<WalletModel> transfer(WalletTransferParams params) async {
    final response = await _apiClient.transferWallet(params.toJson());
    return _parseWalletFromMutation(response.data, ApiConstants.walletTransfer);
  }

  Future<List<WalletRecipientModel>> searchRecipient(String q) async {
    final response = await _apiClient.searchWalletRecipient(q);
    final payload =
        _parsePayload(response.data, ApiConstants.walletRecipientSearch);
    final listData = payload['data'];

    if (listData is! List) {
      return const <WalletRecipientModel>[];
    }

    return listData.whereType<Map>().map((item) {
      return WalletRecipientModel.fromJson(Map<String, dynamic>.from(item));
    }).toList(growable: false);
  }

  WalletModel _parseWalletFromMutation(dynamic raw, String path) {
    final payload = _parsePayload(raw, path);
    final data = payload['data'];

    if (data is! Map) {
      throw _badResponse(path, payload);
    }

    final json = Map<String, dynamic>.from(data);
    final walletRaw = json['wallet'];

    if (walletRaw is Map) {
      return WalletModel.fromJson(Map<String, dynamic>.from(walletRaw));
    }

    return WalletModel.fromJson(json);
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

  String _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }
}
