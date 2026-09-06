import 'package:bakaloo_flutter_app/features/wallet/domain/entities/wallet_recipient_entity.dart';

class WalletRecipientModel {
  const WalletRecipientModel({
    required this.id,
    required this.name,
    required this.phone,
  });

  final String id;
  final String name;
  final String phone;

  factory WalletRecipientModel.fromJson(Map<String, dynamic> json) {
    return WalletRecipientModel(
      id: _toString(json['id']),
      name: _toString(json['name']),
      phone: _toString(json['phone']),
    );
  }

  WalletRecipientEntity toEntity() {
    return WalletRecipientEntity(id: id, name: name, phone: phone);
  }

  static String _toString(Object? value) {
    if (value is String) return value.trim();
    return value?.toString() ?? '';
  }
}
