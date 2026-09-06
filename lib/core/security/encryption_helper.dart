import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';

class EncryptionHelper {
  EncryptionHelper({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _secureStorage;

  Future<HiveAesCipher> getHiveCipher() async {
    final base64Key = await _secureStorage.read(
      key: StorageKeys.hiveEncryptionKey,
    );

    if (base64Key == null || base64Key.isEmpty) {
      final newKey = _generateKey();
      await _secureStorage.write(
        key: StorageKeys.hiveEncryptionKey,
        value: base64Encode(newKey),
      );
      return HiveAesCipher(newKey);
    }

    final decoded = base64Decode(base64Key);
    if (decoded.length != 32) {
      final newKey = _generateKey();
      await _secureStorage.write(
        key: StorageKeys.hiveEncryptionKey,
        value: base64Encode(newKey),
      );
      return HiveAesCipher(newKey);
    }

    return HiveAesCipher(Uint8List.fromList(decoded));
  }

  Uint8List _generateKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (_) => random.nextInt(256));
    return Uint8List.fromList(values);
  }
}
