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
    } else {
      final guest =
          HiveService.settingsBox.get(StorageKeys.guestStorefrontLocation);
      if (guest is Map &&
          guest['token'] is String &&
          (guest['token'] as String).isNotEmpty) {
        options.headers['X-Storefront-Token'] = guest['token'] as String;
      }
    }

    // Attach the customer's B2B/B2C browsing mode to every product-serving
    // call in one place, rather than threading a priceMode param through
    // each individual product endpoint method — see PriceModeNotifier
    // (core/providers/price_mode_provider.dart) for how this is set.
    if ((options.path.contains('/products') ||
            options.path.contains('/theme/tabs') ||
            options.path.contains('/cart') ||
            options.path.contains('/orders')) &&
        !options.queryParameters.containsKey('priceMode')) {
      try {
        final stored =
            HiveService.settingsBox.get(StorageKeys.priceMode) as String?;
        final mode = stored == 'wholesale' ? 'wholesale' : 'retail';
        options.queryParameters['priceMode'] = mode;
        // Cart mutations and order placement use a JSON body. The backend
        // persists separate carts by this mode, so carry the same value in
        // the body as well as the query string.
        if ((options.path.contains('/cart') || options.path.contains('/orders')) &&
            options.data is Map) {
          // Some datasource calls pass a const map. Copy before adding the
          // field so those requests remain safe as well.
          options.data = <String, dynamic>{
            ...Map<String, dynamic>.from(options.data as Map),
            'priceMode': mode,
          };
        }
      } catch (_) {
        // Hive not ready yet (unlikely this late in startup) — default
        // retail pricing on the server side covers this.
      }
    }

    handler.next(options);
  }
}
