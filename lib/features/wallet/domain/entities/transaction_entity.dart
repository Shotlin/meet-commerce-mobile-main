// ignore_for_file: constant_identifier_names

import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_entity.freezed.dart';

enum WalletTransactionType {
  CREDIT,
  DEBIT,
}

WalletTransactionType walletTransactionTypeFromRaw(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return WalletTransactionType.DEBIT;
  }
  final normalized = raw.trim().toUpperCase();
  return normalized == WalletTransactionType.CREDIT.name
      ? WalletTransactionType.CREDIT
      : WalletTransactionType.DEBIT;
}

@freezed
abstract class TransactionEntity with _$TransactionEntity {
  const factory TransactionEntity({
    required String id,
    required WalletTransactionType type,
    required double amount,
    required String description,
    required DateTime createdAt,
  }) = _TransactionEntity;
}
