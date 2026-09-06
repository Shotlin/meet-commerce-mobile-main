import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_entity.freezed.dart';

@freezed
abstract class WalletEntity with _$WalletEntity {
  const factory WalletEntity({
    required double balance,
    @Default('INR') String currency,
  }) = _WalletEntity;
}
