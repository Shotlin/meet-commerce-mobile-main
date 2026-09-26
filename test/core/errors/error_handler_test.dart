import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/core/errors/error_handler.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';

DioException _dioError(DioExceptionType type, {Object? error}) {
  return DioException(
    requestOptions: RequestOptions(path: '/orders'),
    type: type,
    error: error,
  );
}

void main() {
  test('a Failure already attached to the error (e.g. from ConnectivityInterceptor) is returned as-is', () {
    const failure = NetworkFailure(message: "You're offline. Please check your internet connection and try again.");

    final result = handleDioError(_dioError(DioExceptionType.cancel, error: failure));

    expect(result, same(failure));
  });

  test(
    'connectionError (a real request that failed downstream) gets a distinct message from a plain offline/cancel case',
    () {
      final connectionErrorResult = handleDioError(_dioError(DioExceptionType.connectionError));
      final timeoutResult = handleDioError(_dioError(DioExceptionType.connectionTimeout));

      expect(connectionErrorResult, isA<NetworkFailure>());
      expect(timeoutResult, isA<NetworkFailure>());
      // The whole point of the fix: these must no longer share the exact
      // same "check your internet" wording — a request that genuinely
      // left the device and failed downstream (DNS hiccup, dropped
      // socket, backend-side reset) is not the same thing as the device
      // having no network at all, and telling the user "check your
      // internet" for the former is actively misleading when they're
      // demonstrably online.
      expect(connectionErrorResult.message, isNot(equals(timeoutResult.message)));
      expect(connectionErrorResult.message, isNot(contains('check your internet')));
    },
  );

  test('connectionTimeout/sendTimeout/receiveTimeout/cancel still share the true-offline wording', () {
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.cancel,
    ]) {
      final result = handleDioError(_dioError(type));
      expect(result.message, contains('check your internet connection'));
    }
  });
}
