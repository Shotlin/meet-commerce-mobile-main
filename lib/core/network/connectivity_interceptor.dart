import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/network/network_monitor.dart';

class ConnectivityInterceptor extends Interceptor {
  ConnectivityInterceptor(
    this._networkMonitor, {
    this.onOfflineDetected,
  });

  final NetworkMonitor _networkMonitor;
  final VoidCallback? onOfflineDetected;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final isConnected = await _networkMonitor.isConnected;
    if (!isConnected) {
      onOfflineDetected?.call();
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: 'No internet connection',
        ),
      );
      return;
    }

    handler.next(options);
  }
}
