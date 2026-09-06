import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:bakaloo_flutter_app/core/errors/failure.dart';

Failure handleDioError(DioException error) {
  if (error.error case final Failure failure) {
    return failure;
  }

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.cancel:
    case DioExceptionType.connectionError:
      return NetworkFailure(
        message: _extractMessage(
          error.response?.data,
          fallback: 'Please check your internet connection and try again.',
        ),
      );
    case DioExceptionType.badCertificate:
      return const NetworkFailure(
        message: 'Secure connection could not be established.',
      );
    case DioExceptionType.badResponse:
      return _mapResponseError(error.response);
    case DioExceptionType.unknown:
      return UnknownFailure(
        message: _extractMessage(
          error.response?.data ?? error.error,
          fallback: 'Something went wrong. Please try again.',
        ),
      );
  }
}

class ErrorHandlerInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final failure = handleDioError(err);
    handler.next(
      err.copyWith(
        error: failure,
        message: failure.message,
      ),
    );
  }
}

Failure _mapResponseError(Response<dynamic>? response) {
  final statusCode = response?.statusCode;
  final data = response?.data;
  final message = _extractMessage(
    data,
    fallback: 'Unexpected server response received.',
  );

  switch (statusCode) {
    case 400:
      // For validation errors, prefer the first specific field error over
      // the generic "Validation error" top-level message.
      final errors = _extractErrors(data);
      final specificMessage = errors?.isNotEmpty == true ? errors!.first : null;
      return ValidationFailure(
        message: specificMessage ?? message,
        errors: errors,
      );
    case 401:
    case 403:
      return AuthFailure(message: message);
    case 404:
      return NotFoundFailure(message: message);
    case 409:
      return ServerFailure(message: message);
    case 429:
      return RateLimitFailure(
        message: message,
        resetAt: _parseRateLimitReset(response?.headers),
      );
    case 500:
    case 501:
    case 502:
    case 503:
    case 504:
      return ServerFailure(message: message);
    default:
      return UnknownFailure(message: message);
  }
}

String _extractMessage(dynamic data, {required String fallback}) {
  // Requests that force `ResponseType.bytes` (e.g. invoice PDF download)
  // still get bytes back from Dio on a non-2xx error response, even though
  // the backend actually sent a JSON error envelope. Decode it before
  // falling back to a generic message.
  if (data is List<int>) {
    try {
      return _extractMessage(jsonDecode(utf8.decode(data)), fallback: fallback);
    } catch (_) {
      return fallback;
    }
  }

  if (data is Map<String, dynamic>) {
    final message = data['message'] ?? data['error'] ?? data['detail'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
  }

  if (data is String && data.trim().isNotEmpty) {
    return data.trim();
  }

  return fallback;
}

List<String>? _extractErrors(dynamic data) {
  if (data is! Map<String, dynamic>) {
    return null;
  }

  final rawErrors = data['errors'];
  if (rawErrors is List) {
    final values = rawErrors
        .map((dynamic item) {
          if (item is String) {
            return item.trim();
          }
          if (item is Map<String, dynamic>) {
            final value = item['message'] ?? item['msg'] ?? item['error'];
            if (value is String) {
              return value.trim();
            }
          }
          return null;
        })
        .whereType<String>()
        .where((String value) => value.isNotEmpty)
        .toList();

    return values.isEmpty ? null : values;
  }

  return null;
}

DateTime? _parseRateLimitReset(Headers? headers) {
  final rawHeader = headers?.value('x-ratelimit-reset');
  if (rawHeader == null || rawHeader.trim().isEmpty) {
    return null;
  }

  final trimmed = rawHeader.trim();
  final epochValue = int.tryParse(trimmed);
  if (epochValue != null) {
    final milliseconds =
        epochValue > 9999999999 ? epochValue : epochValue * 1000;
    return DateTime.fromMillisecondsSinceEpoch(
      milliseconds,
      isUtc: true,
    ).toLocal();
  }

  return DateTime.tryParse(trimmed)?.toLocal();
}
