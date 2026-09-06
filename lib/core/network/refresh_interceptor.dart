import 'package:dio/dio.dart';
import 'package:synchronized/synchronized.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/constants/app_constants.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/core/storage/secure_storage_service.dart';

class RefreshInterceptor extends Interceptor {
  RefreshInterceptor({
    required Dio dio,
    required SecureStorageService secureStorageService,
    this.onForceLogout,
    this.onTokenRefreshed,
    Dio? refreshDio,
  })  : _dio = dio,
        _secureStorageService = secureStorageService,
        _refreshDio = refreshDio;

  final Dio _dio;
  final SecureStorageService _secureStorageService;
  // Injectable for tests (a fake Dio can simulate transient vs. confirmed-
  // rejection failures on the refresh call). Production leaves this null
  // and gets a real, freshly-built Dio per refresh attempt, same as before.
  final Dio? _refreshDio;
  final Lock _lock = Lock();
  final void Function()? onForceLogout;
  final void Function(String newAccessToken)? onTokenRefreshed;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final requestOptions = err.requestOptions;
    final hasRetried = requestOptions.extra['retried'] == true;

    if (statusCode != 401 ||
        hasRetried ||
        requestOptions.path == ApiConstants.refreshToken) {
      handler.next(err);
      return;
    }

    try {
      final response = await _lock.synchronized(() async {
        final latestAccessToken = await _secureStorageService.getAccessToken();
        final currentHeader =
            requestOptions.headers['Authorization'] as String?;
        final currentToken = currentHeader?.replaceFirst('Bearer ', '').trim();

        if (latestAccessToken != null &&
            latestAccessToken.isNotEmpty &&
            latestAccessToken != currentToken) {
          return _retryRequest(
            requestOptions,
            latestAccessToken,
          );
        }

        final refreshToken = await _secureStorageService.getRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          await _forceLogout();
          throw _authDioException(
            requestOptions,
            const AuthFailure(
              message: 'Your session has expired. Please sign in again.',
            ),
          );
        }

        final refreshDio = _refreshDio ??
            Dio(
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

        final Response<dynamic> refreshResponse;
        try {
          refreshResponse = await refreshDio.post<dynamic>(
            ApiConstants.refreshToken,
            data: <String, dynamic>{'refreshToken': refreshToken},
          );
        } on DioException catch (refreshError) {
          final int? status = refreshError.response?.statusCode;
          final bool isConfirmedRejection =
              refreshError.type == DioExceptionType.badResponse &&
                  (status == 401 || status == 403);

          if (!isConfirmedRejection) {
            // Transient failure (timeout, offline, DNS hiccup, 5xx) — we
            // have no evidence the refresh token itself is bad. Forcing a
            // logout here would wipe a perfectly valid session over a
            // momentary network blip, which is indistinguishable from the
            // "logged out every few days" symptom this guards against.
            // Only the request that triggered this refresh fails; the
            // session (and its 365-day refresh token) survives for the
            // next attempt.
            throw _authDioException(
              requestOptions,
              const AuthFailure(
                message: 'Could not reach the server. Please try again.',
              ),
            );
          }

          // The refresh token itself is dead (expired/revoked server-side —
          // e.g. a newer login elsewhere bumped session_version). No amount
          // of retrying fixes this, and this failure is a DioException, so
          // without this catch it falls straight into the `on DioException`
          // branch below and is rejected as-is — forceLogout() never runs,
          // and the user is stuck: every subsequent request keeps failing
          // the exact same way with no path back to the login screen.
          await _forceLogout();
          throw _authDioException(
            requestOptions,
            const AuthFailure(
              message: 'Your session has expired. Please sign in again.',
            ),
          );
        }

        final tokens = _extractTokenPair(refreshResponse.data);
        final accessToken = tokens['accessToken'];
        final nextRefreshToken = tokens['refreshToken'];

        if (accessToken == null ||
            accessToken.isEmpty ||
            nextRefreshToken == null ||
            nextRefreshToken.isEmpty) {
          await _forceLogout();
          throw _authDioException(
            requestOptions,
            const AuthFailure(
              message: 'Unable to renew your session. Please sign in again.',
            ),
          );
        }

        await _secureStorageService.saveTokens(
          accessToken: accessToken,
          refreshToken: nextRefreshToken,
        );
        onTokenRefreshed?.call(accessToken);

        return _retryRequest(requestOptions, accessToken);
      });

      handler.resolve(response);
    } on DioException catch (dioException) {
      handler.reject(dioException);
    } catch (_) {
      await _forceLogout();
      handler.reject(
        _authDioException(
          requestOptions,
          const AuthFailure(
            message: 'Your session has expired. Please sign in again.',
          ),
        ),
      );
    }
  }

  Future<Response<dynamic>> _retryRequest(
    RequestOptions requestOptions,
    String accessToken,
  ) {
    final options = requestOptions.copyWith(
      headers: <String, dynamic>{
        ...requestOptions.headers,
        'Authorization': 'Bearer $accessToken',
      },
      extra: <String, dynamic>{
        ...requestOptions.extra,
        'retried': true,
      },
    );

    return _dio.fetch<dynamic>(options);
  }

  Future<void> _forceLogout() async {
    await _secureStorageService.clearAll();
    onForceLogout?.call();
  }

  DioException _authDioException(
    RequestOptions requestOptions,
    AuthFailure failure,
  ) {
    return DioException(
      requestOptions: requestOptions,
      response: Response<dynamic>(
        requestOptions: requestOptions,
        statusCode: 401,
      ),
      type: DioExceptionType.badResponse,
      error: failure,
      message: failure.message,
    );
  }

  Map<String, String?> _extractTokenPair(dynamic data) {
    if (data is Map<String, dynamic>) {
      final tokenData = data['data'];
      if (tokenData is Map<String, dynamic>) {
        return <String, String?>{
          'accessToken': tokenData['accessToken'] as String?,
          'refreshToken': tokenData['refreshToken'] as String?,
        };
      }

      return <String, String?>{
        'accessToken': data['accessToken'] as String?,
        'refreshToken': data['refreshToken'] as String?,
      };
    }

    return const <String, String?>{
      'accessToken': null,
      'refreshToken': null,
    };
  }
}
