import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/core/storage/secure_storage_service.dart';

class ApiInterceptor extends Interceptor {
  ApiInterceptor(this._secureStorageService);

  final SecureStorageService _secureStorageService;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _secureStorageService.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // Attach the customer's B2B/B2C browsing mode to every product-serving
    // call in one place, rather than threading a priceMode param through
    // each individual product endpoint method — see PriceModeNotifier
    // (core/providers/price_mode_provider.dart) for how this is set.
    if (options.path.contains('/products') &&
        !options.queryParameters.containsKey('priceMode')) {
      try {
        final stored =
            HiveService.settingsBox.get(StorageKeys.priceMode) as String?;
        options.queryParameters['priceMode'] =
            stored == 'wholesale' ? 'wholesale' : 'retail';
      } catch (_) {
        // Hive not ready yet (unlikely this late in startup) — default
        // retail pricing on the server side covers this.
      }
    }

    handler.next(options);
  }
}
