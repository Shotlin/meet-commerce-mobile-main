import 'package:bakaloo_flutter_app/features/wallet/domain/entities/transaction_entity.dart';

class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final WalletTransactionType type;
  final double amount;
  final String description;
  final DateTime createdAt;

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: _toString(json['id']),
      type: walletTransactionTypeFromRaw(_toString(json['type'])),
      amount: _toDouble(json['amount']),
      description: _toString(
        json['description'],
        fallback: 'Wallet transaction',
      ),
      createdAt: _toDateTime(json['createdAt'] ?? json['created_at']) ??
          DateTime.now(),
    );
  }

  TransactionEntity toEntity() {
    return TransactionEntity(
      id: id,
      type: type,
      amount: amount,
      description: description,
      createdAt: createdAt,
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

  static DateTime? _toDateTime(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    if (value is int) {
      final milliseconds = value > 9999999999 ? value : value * 1000;
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }
    return null;
  }
}
