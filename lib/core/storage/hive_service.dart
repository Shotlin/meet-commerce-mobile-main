import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';
import 'package:bakaloo_flutter_app/core/security/encryption_helper.dart';

class HiveService {
  const HiveService();

  static late Box<dynamic> productsBox;
  static late Box<dynamic> categoriesBox;
  static late Box<dynamic> ordersBox;
  static late Box<dynamic> searchHistoryBox;
  static late Box<dynamic> recentlyViewedBox;
  static late Box<dynamic> bannersBox;
  static late Box<dynamic> userBox;
  static late Box<dynamic> settingsBox;
  static late Box<dynamic> cacheMetaBox;
  static late Box<dynamic> remoteThemeBox;

  static Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(directory.path);
    final cipher = await EncryptionHelper().getHiveCipher();

    productsBox = await Hive.openBox<dynamic>(StorageKeys.productsBox);
    categoriesBox = await Hive.openBox<dynamic>(StorageKeys.categoriesBox);
    // Encrypted like userBox/settingsBox — this box holds full order
    // payloads (amounts, delivery addresses, payment status), unlike the
    // public catalog/category caches above, so it doesn't belong in a
    // plaintext box readable straight off disk on a rooted device.
    // _openSensitiveBox() transparently migrates any existing plaintext
    // ordersBox from a previous app version into the encrypted one.
    ordersBox = await _openSensitiveBox(StorageKeys.ordersBox, cipher);
    searchHistoryBox =
        await Hive.openBox<dynamic>(StorageKeys.searchHistoryBox);
    recentlyViewedBox =
        await Hive.openBox<dynamic>(StorageKeys.recentlyViewedBox);
    bannersBox = await Hive.openBox<dynamic>(StorageKeys.bannersBox);
    userBox = await _openSensitiveBox(StorageKeys.userBox, cipher);
    settingsBox = await _openSensitiveBox(StorageKeys.settingsBox, cipher);
    cacheMetaBox = await Hive.openBox<dynamic>(StorageKeys.cacheMetaBox);
    remoteThemeBox = await Hive.openBox<dynamic>(StorageKeys.remoteThemeBox);
  }

  static bool isFresh(String key, Duration ttl) {
    final value = cacheMetaBox.get(key);
    DateTime? cachedAt;

    if (value is DateTime) {
      cachedAt = value;
    } else if (value is String) {
      cachedAt = DateTime.tryParse(value);
    }

    if (cachedAt == null) {
      return false;
    }

    return DateTime.now().difference(cachedAt) < ttl;
  }

  static Future<void> markCached(String key) {
    return cacheMetaBox.put(key, DateTime.now());
  }

  static Future<void> invalidate(String key) {
    return cacheMetaBox.delete(key);
  }

  static Future<Box<dynamic>> _openSensitiveBox(
    String boxName,
    HiveAesCipher cipher,
  ) async {
    try {
      return await Hive.openBox<dynamic>(
        boxName,
        encryptionCipher: cipher,
      );
    } catch (_) {
      Map<dynamic, dynamic> existingData = <dynamic, dynamic>{};

      if (Hive.isBoxOpen(boxName)) {
        final openBox = Hive.box<dynamic>(boxName);
        existingData = Map<dynamic, dynamic>.from(openBox.toMap());
        await openBox.close();
      } else {
        try {
          final plainBox = await Hive.openBox<dynamic>(boxName);
          existingData = Map<dynamic, dynamic>.from(plainBox.toMap());
          await plainBox.close();
        } catch (_) {
          existingData = <dynamic, dynamic>{};
        }
      }

      await Hive.deleteBoxFromDisk(boxName);
      final encryptedBox = await Hive.openBox<dynamic>(
        boxName,
        encryptionCipher: cipher,
      );
      if (existingData.isNotEmpty) {
        await encryptedBox.putAll(existingData);
      }
      return encryptedBox;
    }
  }
}
