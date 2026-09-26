import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/core/network/network_monitor.dart';

/// `connectivity_plus`'s `checkConnectivity()` is a link-layer check (is a
/// radio/adapter up), not a real reachability probe — it's well documented
/// to occasionally report a stale/transient `none` for a brief moment
/// during a cellular handoff or right after the app resumes, even though
/// the device genuinely has working internet a moment later. Rejecting a
/// real request outright on a single such reading blocks something that
/// would otherwise have succeeded (confirmed live: the backend was fully
/// reachable at the time users hit this). A single re-check after a short
/// delay filters out that transient case without meaningfully slowing down
/// a request when the device is genuinely offline.
const _recheckDelay = Duration(milliseconds: 300);

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
    if (await _networkMonitor.isConnected) {
      handler.next(options);
      return;
    }

    await Future<void>.delayed(_recheckDelay);
    if (await _networkMonitor.isConnected) {
      handler.next(options);
      return;
    }

    onOfflineDetected?.call();
    // Wrapped in a real `Failure` (not a raw string) so `handleDioError`'s
    // `case final Failure failure` short-circuit returns it directly —
    // this preflight "genuinely offline" case can never be conflated with
    // a request that was actually attempted and failed downstream (a
    // separate, distinctly-worded case in error_handler.dart).
    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        error: const NetworkFailure(
          message: "You're offline. Please check your internet connection and try again.",
        ),
      ),
    );
  }
}
