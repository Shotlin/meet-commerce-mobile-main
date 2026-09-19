import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_certificate_pinning/http_certificate_pinning.dart';

import 'package:bakaloo_flutter_app/core/config/app_config.dart';
import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';

class CertificatePinning {
  CertificatePinning._();

  static Interceptor? createInterceptor() {
    if (kDebugMode) {
      return null;
    }

    final baseUrl = ApiConstants.baseUrl.trim();
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.scheme.toLowerCase() != 'https') {
      return null;
    }

    final fingerprints = _allowedFingerprints;
    if (fingerprints.isEmpty) {
      return null;
    }

    return CertificatePinningInterceptor(
      allowedSHAFingerprints: fingerprints,
      timeout: 50,
    );
  }

  static List<String> get _allowedFingerprints {
    final pins = <String>[
      if (AppConfig.sslPinSha256.isNotEmpty) AppConfig.sslPinSha256,
      if (AppConfig.sslPinSha256Backup.isNotEmpty)
        AppConfig.sslPinSha256Backup,
      ...AppConfig.sslPinSha256List
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty),
    ];
    return pins.toSet().toList(growable: false);
  }
}
