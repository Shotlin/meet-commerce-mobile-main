import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/constants/app_constants.dart';
import 'package:bakaloo_flutter_app/core/network/app_availability_provider.dart';
import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/network/api_interceptor.dart';
import 'package:bakaloo_flutter_app/core/network/availability_interceptor.dart';
import 'package:bakaloo_flutter_app/core/network/connectivity_interceptor.dart';
import 'package:bakaloo_flutter_app/core/network/loading_activity_interceptor.dart';
import 'package:bakaloo_flutter_app/core/network/logger_interceptor.dart';
import 'package:bakaloo_flutter_app/core/network/network_monitor.dart';
import 'package:bakaloo_flutter_app/core/network/refresh_interceptor.dart';
import 'package:bakaloo_flutter_app/core/network/network_activity_provider.dart';
import 'package:bakaloo_flutter_app/core/security/certificate_pinning.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_service.dart';
import 'package:bakaloo_flutter_app/core/storage/secure_storage_service.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';

class DioClient {
  DioClient._();

  static Dio create(Ref ref) {
    final secureStorageService = SecureStorageService();
    final availabilityController = ref.read(appAvailabilityProvider.notifier);
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(
          seconds: AppConstants.connectTimeoutSeconds,
        ),
        receiveTimeout: const Duration(
          seconds: AppConstants.receiveTimeoutSeconds,
        ),
        contentType: 'application/json',
      ),
    );

    dio.interceptors.addAll(<Interceptor>[
      LoadingActivityInterceptor(ref.read(networkActivityProvider.notifier)),
      ConnectivityInterceptor(
        NetworkMonitor(),
        onOfflineDetected: availabilityController.reportOffline,
      ),
      if (CertificatePinning.createInterceptor() case final pinning?) pinning,
      ApiInterceptor(secureStorageService),
      RefreshInterceptor(
        dio: dio,
        secureStorageService: secureStorageService,
        onTokenRefreshed: (accessToken) {
          ref.read(socketServiceProvider).reconnect(accessToken);
        },
        // When refresh token is also expired, force-logout the user so they
        // are redirected to the phone login screen instead of seeing a raw
        // "Invalid or expired refresh token" snackbar.
        onForceLogout: () {
          try {
            ref.read(authNotifierProvider.notifier).logout();
          } catch (_) {
            // Logout is best-effort — if the notifier is already disposed,
            // the user will be redirected on the next navigation attempt.
          }
        },
      ),
    ]);

    final logger = createLoggerInterceptor();
    if (logger != null) {
      dio.interceptors.add(logger);
    }

    dio.interceptors.add(ErrorHandlerInterceptor());
    dio.interceptors.add(AvailabilityInterceptor(availabilityController));
    return dio;
  }
}
