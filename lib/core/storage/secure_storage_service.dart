import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';

class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(
      key: StorageKeys.accessToken,
      value: accessToken,
    );
    await _storage.write(
      key: StorageKeys.refreshToken,
      value: refreshToken,
    );
  }

  Future<String?> getAccessToken() {
    return _storage.read(key: StorageKeys.accessToken);
  }

  Future<String?> getRefreshToken() {
    return _storage.read(key: StorageKeys.refreshToken);
  }

  Future<void> saveUserId(String userId) {
    return _storage.write(
      key: StorageKeys.userId,
      value: userId,
    );
  }

  Future<String?> getUserId() {
    return _storage.read(key: StorageKeys.userId);
  }

  Future<void> clearAll() {
    return _storage.deleteAll();
  }
}
