import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_recipient_entity.freezed.dart';

@freezed
abstract class WalletRecipientEntity with _$WalletRecipientEntity {
  const factory WalletRecipientEntity({
    required String id,
    required String name,
    required String phone,
  }) = _WalletRecipientEntity;
}
