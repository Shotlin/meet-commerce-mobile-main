import 'package:bakaloo_flutter_app/features/wallet/domain/entities/wallet_entity.dart';

class WalletModel {
  const WalletModel({
    required this.balance,
    required this.currency,
  });

  final double balance;
  final String currency;

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      balance: _toDouble(json['balance']),
      currency: _toString(json['currency'], fallback: 'INR'),
    );
  }

  WalletEntity toEntity() {
    return WalletEntity(
      balance: balance,
      currency: currency,
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _toString(Object? value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }
}
