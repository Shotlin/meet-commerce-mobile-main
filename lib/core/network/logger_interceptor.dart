import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

Interceptor? createLoggerInterceptor() {
  if (kReleaseMode) {
    return null;
  }
  return const _SafeLoggerInterceptor();
}

class _SafeLoggerInterceptor extends Interceptor {
  const _SafeLoggerInterceptor();

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (kReleaseMode) {
      handler.next(options);
      return;
    }

    final method = options.method.toUpperCase();
    debugPrint('➡️ [$method] ${options.uri}');
    if (options.headers.isNotEmpty) {
      debugPrint('Headers: ${_safeEncode(_maskDynamic(options.headers))}');
    }
    if (options.queryParameters.isNotEmpty) {
      debugPrint(
        'Query: ${_safeEncode(_maskDynamic(options.queryParameters))}',
      );
    }
    if (options.data != null) {
      debugPrint('Body: ${_safeEncode(_maskDynamic(options.data))}');
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (kReleaseMode) {
      handler.next(response);
      return;
    }

    final method = response.requestOptions.method.toUpperCase();
    final path = response.requestOptions.uri;
    debugPrint('✅ [$method] ${response.statusCode} $path');
    if (response.data != null) {
      debugPrint('Response: ${_safeEncode(_maskDynamic(response.data))}');
    }
    handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    if (kReleaseMode) {
      handler.next(err);
      return;
    }

    final method = err.requestOptions.method.toUpperCase();
    debugPrint(
      '❌ [$method] ${err.requestOptions.uri} :: ${err.message ?? 'Unknown error'}',
    );
    final responseData = err.response?.data;
    if (responseData != null) {
      debugPrint('Error body: ${_safeEncode(_maskDynamic(responseData))}');
    }
    handler.next(err);
  }

  Object? _maskDynamic(Object? value, {String? key}) {
    if (value is Map) {
      return value.map((rawKey, rawValue) {
        final currentKey = rawKey.toString();
        return MapEntry<String, Object?>(
          currentKey,
          _maskDynamic(rawValue, key: currentKey),
        );
      });
    }

    if (value is List) {
      return value
          .map((item) => _maskDynamic(item, key: key))
          .toList(growable: false);
    }

    if (value is String) {
      if (_isTokenKey(key) || _looksLikeBearer(value)) {
        return _maskToken(value);
      }
      if (_isPhoneKey(key) || _looksLikePhone(value)) {
        return _maskPhone(value);
      }
      return value;
    }

    return value;
  }

  bool _isTokenKey(String? key) {
    if (key == null) {
      return false;
    }
    final normalized = key.toLowerCase();
    return normalized.contains('authorization') || normalized.contains('token');
  }

  bool _isPhoneKey(String? key) {
    if (key == null) {
      return false;
    }
    return key.toLowerCase().contains('phone');
  }

  bool _looksLikeBearer(String value) {
    return value.toLowerCase().startsWith('bearer ');
  }

  bool _looksLikePhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 10 && digits.length <= 14;
  }

  String _maskToken(String token) {
    final trimmed = token.trim();
    if (trimmed.length <= 10) {
      return '***';
    }
    return '${trimmed.substring(0, 5)}***${trimmed.substring(trimmed.length - 3)}';
  }

  String _maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) {
      return '***';
    }
    return '${digits.substring(0, 2)}******${digits.substring(digits.length - 2)}';
  }

  String _safeEncode(Object? payload) {
    try {
      return jsonEncode(payload);
    } catch (_) {
      return payload.toString();
    }
  }
}
