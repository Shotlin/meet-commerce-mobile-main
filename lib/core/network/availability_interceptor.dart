import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/network/app_availability_provider.dart';

class AvailabilityInterceptor extends Interceptor {
  AvailabilityInterceptor(this._controller);

  final AppAvailabilityNotifier _controller;

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _controller.reportHealthy();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_isServiceUnavailable(err)) {
      _controller.reportServiceUnavailable();
    }
    handler.next(err);
  }

  bool _isServiceUnavailable(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode != null &&
        (statusCode == 502 || statusCode == 503 || statusCode == 504)) {
      return true;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        final rawError = '${error.error ?? ''}'.toLowerCase();
        return !rawError.contains('no internet');
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return false;
    }
  }
}
