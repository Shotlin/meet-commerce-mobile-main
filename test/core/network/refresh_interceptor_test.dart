import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:bakaloo_flutter_app/core/network/refresh_interceptor.dart';
import 'package:bakaloo_flutter_app/core/storage/secure_storage_service.dart';

class _MockSecureStorageService extends Mock implements SecureStorageService {}

class _MockDio extends Mock implements Dio {}

class _FakeRequestOptions extends Fake implements RequestOptions {}

/// Minimal HttpClientAdapter stand-in so the refresh call inside the
/// interceptor gets an exact, scripted result instead of a real network
/// call — no extra test-only packages needed, just Dio's own adapter API.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);

  final Future<ResponseBody> Function() _respond;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _respond();
  }
}

/// A [Dio] whose refresh-call adapter always throws [type] — simulating a
/// transport-level failure (timeout/offline/DNS) that never reached the
/// server, so nothing is known about whether the refresh token is valid.
Dio _dioThatFailsTransiently(DioExceptionType type) {
  return Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = _ScriptedAdapter(() async {
      throw DioException(
        requestOptions: RequestOptions(path: '/auth/refresh-token'),
        type: type,
      );
    });
}

/// A [Dio] whose refresh-call adapter returns [statusCode] with [body] —
/// used to simulate the backend explicitly rejecting the refresh token
/// (401/403) or succeeding (200) with a fresh token pair.
Dio _dioThatResponds(int statusCode, Map<String, dynamic> body) {
  return Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = _ScriptedAdapter(() async {
      return ResponseBody.fromString(
        jsonEncode(body),
        statusCode,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    });
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRequestOptions());
  });

  late _MockSecureStorageService storage;
  late _MockDio outerDio;
  late RequestOptions originalRequest;
  late DioException triggeringError;
  late bool forceLogoutCalled;

  setUp(() {
    storage = _MockSecureStorageService();
    outerDio = _MockDio();
    forceLogoutCalled = false;

    when(() => storage.getAccessToken())
        .thenAnswer((_) async => 'expired-access-token');
    when(() => storage.getRefreshToken())
        .thenAnswer((_) async => 'stored-refresh-token');
    when(() => storage.clearAll()).thenAnswer((_) async {});
    when(
      () => storage.saveTokens(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
      ),
    ).thenAnswer((_) async {});

    originalRequest = RequestOptions(
      path: '/orders',
      headers: <String, dynamic>{
        'Authorization': 'Bearer expired-access-token',
      },
    );
    triggeringError = DioException(
      requestOptions: originalRequest,
      response: Response<dynamic>(
        requestOptions: originalRequest,
        statusCode: 401,
      ),
      type: DioExceptionType.badResponse,
    );
  });

  RefreshInterceptor buildInterceptor(Dio refreshDio) {
    return RefreshInterceptor(
      dio: outerDio,
      secureStorageService: storage,
      refreshDio: refreshDio,
      onForceLogout: () => forceLogoutCalled = true,
    );
  }

  group('RefreshInterceptor.onError — transient refresh failures', () {
    for (final type in <DioExceptionType>[
      DioExceptionType.connectionTimeout,
      DioExceptionType.connectionError,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
    ]) {
      test('$type does NOT force logout or clear the stored session', () async {
        final interceptor = buildInterceptor(_dioThatFailsTransiently(type));
        final handler = _RecordingHandler();

        await interceptor.onError(triggeringError, handler);

        expect(forceLogoutCalled, isFalse);
        verifyNever(() => storage.clearAll());
        // The one request that was mid-flight still fails — that's
        // expected and fine — but the session itself must survive so the
        // very next request gets a normal chance to refresh again.
        expect(handler.rejectedWith, isNotNull);
      });
    }
  });

  group('RefreshInterceptor.onError — confirmed refresh-token rejection', () {
    test('a 401 from the refresh endpoint itself forces logout', () async {
      final interceptor = buildInterceptor(
        _dioThatResponds(401, <String, dynamic>{
          'success': false,
          'message': 'Invalid or expired refresh token',
        }),
      );
      final handler = _RecordingHandler();

      await interceptor.onError(triggeringError, handler);

      expect(forceLogoutCalled, isTrue);
      verify(() => storage.clearAll()).called(1);
    });

    test('a 403 from the refresh endpoint itself forces logout', () async {
      final interceptor = buildInterceptor(
        _dioThatResponds(403, <String, dynamic>{'success': false}),
      );
      final handler = _RecordingHandler();

      await interceptor.onError(triggeringError, handler);

      expect(forceLogoutCalled, isTrue);
      verify(() => storage.clearAll()).called(1);
    });
  });

  group('RefreshInterceptor.onError — successful refresh', () {
    test('rotates tokens, saves them, and retries the original request',
        () async {
      when(() => outerDio.fetch<dynamic>(any())).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: originalRequest,
          statusCode: 200,
          data: <String, dynamic>{'ok': true},
        ),
      );

      final interceptor = buildInterceptor(
        _dioThatResponds(200, <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'accessToken': 'new-access-token',
            'refreshToken': 'new-refresh-token',
          },
        }),
      );
      final handler = _RecordingHandler();

      await interceptor.onError(triggeringError, handler);

      expect(forceLogoutCalled, isFalse);
      verify(
        () => storage.saveTokens(
          accessToken: 'new-access-token',
          refreshToken: 'new-refresh-token',
        ),
      ).called(1);
      verify(() => outerDio.fetch<dynamic>(any())).called(1);
      expect(handler.resolvedWith, isNotNull);
    });
  });
}

/// Records what an [ErrorInterceptorHandler] was told to do. Extends the
/// real class (rather than implementing it) purely to satisfy its private
/// abstract plumbing — resolve/reject/next are overridden to just capture
/// the outcome instead of delegating to the base completer, since nothing
/// in these tests awaits `handler.future`, and completing it unawaited
/// surfaces as an unhandled-error test failure.
class _RecordingHandler extends ErrorInterceptorHandler {
  Response<dynamic>? resolvedWith;
  DioException? rejectedWith;

  @override
  void resolve(Response<dynamic> response) {
    resolvedWith = response;
  }

  @override
  void reject(DioException error) {
    rejectedWith = error;
  }

  @override
  void next(DioException error) {
    rejectedWith = error;
  }
}
