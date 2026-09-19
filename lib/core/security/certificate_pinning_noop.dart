import 'package:dio/dio.dart';

/// TLS validation is performed by the browser. JavaScript cannot implement
/// application certificate pinning, so Web deliberately installs no pinning
/// interceptor.
class CertificatePinning {
  CertificatePinning._();

  static Interceptor? createInterceptor() => null;
}
