/// Build-time configuration shared by every supported platform.
///
/// Values passed with `--dart-define` are compiled into the client and are
/// therefore public on Web. Only public endpoints and non-secret identifiers
/// belong here; credentials and backend signing material must never be added.
import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  static const String _baseUrl = String.fromEnvironment('BASE_URL');
  static const String _socketUrl = String.fromEnvironment('SOCKET_URL');
  static const String _webBaseUrl = String.fromEnvironment('WEB_BASE_URL');
  static const String _sslPinSha256 = String.fromEnvironment('SSL_PIN_SHA256');
  static const String _sslPinSha256Backup =
      String.fromEnvironment('SSL_PIN_SHA256_BACKUP');
  static const String _sslPinSha256List =
      String.fromEnvironment('SSL_PIN_SHA256_LIST');
  // Remote marketing artwork is dashboard-controlled and therefore cannot
  // be reviewed at compile time. Keep it opt-in on Web until the asset owner
  // confirms that the active campaign imagery is Bakaloo-branded.
  static const String _allowRemoteMarketingAssets =
      String.fromEnvironment('ALLOW_REMOTE_MARKETING_ASSETS');

  static String get baseUrl => _baseUrl.trim().isNotEmpty
      ? _baseUrl.trim()
      : kIsWeb
          ? '${Uri.base.origin}/api/v1'
          : '';
  static String get socketUrl => _socketUrl.trim().isNotEmpty
      ? _socketUrl.trim()
      : kIsWeb
          ? Uri.base.origin
          : '';
  static String get webBaseUrl => _webBaseUrl.trim().isNotEmpty
      ? _webBaseUrl.trim()
      : kIsWeb
          ? Uri.base.origin
          : '';
  static String get sslPinSha256 => _sslPinSha256.trim();
  static String get sslPinSha256Backup => _sslPinSha256Backup.trim();
  static String get sslPinSha256List => _sslPinSha256List.trim();

  /// Whether Web may render dashboard-provided campaign artwork. Product,
  /// category and other commerce data remain live regardless of this flag.
  /// Native builds preserve their existing dashboard behaviour.
  static bool get allowRemoteMarketingAssets =>
      !kIsWeb || _allowRemoteMarketingAssets.trim().toLowerCase() == 'true';
}
