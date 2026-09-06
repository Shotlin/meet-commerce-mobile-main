import 'dart:async';
import 'dart:convert';

// ignore: implementation_imports
import 'package:dotlottie_loader/src/dotlottie_converter.dart';
import 'package:dotlottie_loader/dotlottie_loader.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';

class LoadedRemoteAnimation {
  const LoadedRemoteAnimation({
    required this.bytes,
    required this.dotLottie,
    required this.resolvedUrl,
  });

  final Uint8List bytes;
  final DotLottie dotLottie;
  final String resolvedUrl;
}

class RemoteAnimationLoader {
  RemoteAnimationLoader._();

  static final Dio _dio = Dio(
    BaseOptions(
      responseType: ResponseType.bytes,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
      headers: <String, String>{
        'Accept': 'application/octet-stream, application/json',
      },
      validateStatus: (int? status) => status != null && status < 500,
    ),
  );
  static final Map<String, LoadedRemoteAnimation> _cache =
      <String, LoadedRemoteAnimation>{};
  static final Map<String, Future<LoadedRemoteAnimation>> _inFlight =
      <String, Future<LoadedRemoteAnimation>>{};

  static Future<LoadedRemoteAnimation> load(String rawUrl) async {
    final String url = rawUrl.trim();
    final LoadedRemoteAnimation? cached = _cache[url];
    if (cached != null) {
      return cached;
    }

    final Future<LoadedRemoteAnimation>? inFlight = _inFlight[url];
    if (inFlight != null) {
      return inFlight;
    }

    final Future<LoadedRemoteAnimation> future = _loadInternal(url);
    _inFlight[url] = future;

    try {
      return await future;
    } finally {
      if (identical(_inFlight[url], future)) {
        _inFlight.remove(url);
      }
    }
  }

  static Future<LoadedRemoteAnimation> _loadInternal(String url) async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (final String candidateUrl in _candidateUrls(url)) {
      try {
        final Uint8List bytes = await _downloadBytes(candidateUrl);
        final DotLottie dotLottie = await DotLottieConverter.fromBytes(
          bytes,
          name: candidateUrl,
        );
        final LoadedRemoteAnimation loaded = LoadedRemoteAnimation(
          bytes: bytes,
          dotLottie: dotLottie,
          resolvedUrl: candidateUrl,
        );
        _cache[url] = loaded;
        _cache[candidateUrl] = loaded;
        return loaded;
      } catch (error, stackTrace) {
        assert(() {
          debugPrint(
            '[RemoteAnimationLoader] Failed $candidateUrl: $error',
          );
          return true;
        }());
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }

    Error.throwWithStackTrace(
      lastError ?? Exception('Failed to load remote animation: $url'),
      lastStackTrace ?? StackTrace.current,
    );
  }

  static List<String> _candidateUrls(String url) {
    final Set<String> candidates = <String>{};
    final String lowerUrl = url.toLowerCase();
    final bool isCloudinaryRaw = lowerUrl.contains('/raw/upload/');
    final bool hasKnownExtension =
        lowerUrl.endsWith('.lottie') || lowerUrl.endsWith('.json');

    final List<String> directCandidates = <String>[
      if (isCloudinaryRaw && !hasKnownExtension) ...<String>[
        '$url.lottie',
        '$url.json',
      ],
      url,
    ];

    if (isCloudinaryRaw) {
      for (final String directUrl in directCandidates) {
        final String? proxiedUrl = ApiConstants.proxyMediaUrl(directUrl);
        if (proxiedUrl != null && proxiedUrl != directUrl) {
          final Uri? proxiedUri = Uri.tryParse(proxiedUrl);
          if (proxiedUri != null) {
            candidates.add(
              proxiedUri.replace(
                queryParameters: <String, String>{
                  ...proxiedUri.queryParameters,
                  'encoding': 'base64',
                },
              ).toString(),
            );
          } else {
            candidates.add(proxiedUrl);
          }
        }
      }
    }

    candidates.addAll(directCandidates);

    return candidates.toList(growable: false);
  }

  static Future<Uint8List> _downloadBytes(String url) async {
    final Uri? uri = Uri.tryParse(url);
    final bool expectsBase64Proxy =
        uri != null &&
        uri.path.contains('/uploads/proxy') &&
        uri.queryParameters['encoding'] == 'base64';

    if (expectsBase64Proxy) {
      final Response<dynamic> response = await _dio.get<dynamic>(
        url,
        options: Options(responseType: ResponseType.json),
      );
      final int statusCode = response.statusCode ?? 0;
      if (statusCode != 200) {
        throw DioException.badResponse(
          statusCode: statusCode,
          requestOptions: response.requestOptions,
          response: response,
        );
      }

      final dynamic payload = response.data;
      if (payload is! Map || payload['success'] != true || payload['data'] is! Map) {
        throw Exception('Invalid animation proxy payload: $url');
      }

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(payload['data'] as Map);
      final String? base64Payload = data['base64'] as String?;
      if (base64Payload == null || base64Payload.isEmpty) {
        throw Exception('Empty animation proxy payload: $url');
      }

      return base64Decode(base64Payload);
    }

    final Response<List<int>> response = await _dio.get<List<int>>(url);
    final int statusCode = response.statusCode ?? 0;
    if (statusCode != 200) {
      throw DioException.badResponse(
        statusCode: statusCode,
        requestOptions: response.requestOptions,
        response: response,
      );
    }

    final List<int>? payload = response.data;
    if (payload == null || payload.isEmpty) {
      throw Exception('Empty animation file: $url');
    }

    return payload is Uint8List ? payload : Uint8List.fromList(payload);
  }
}
