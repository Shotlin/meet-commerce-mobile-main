import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';

/// App-wide splash screen image + header logo, editable from the dashboard.
/// Both fields are nullable by design: null means "use the bundled default
/// asset" — the app ships both images, this config only overrides them.
class BrandingConfig {
  const BrandingConfig({
    required this.splashImageUrl,
    required this.logoImageUrl,
  });

  final String? splashImageUrl;
  final String? logoImageUrl;

  factory BrandingConfig.fromJson(Map<String, dynamic> json) {
    return BrandingConfig(
      splashImageUrl: ApiConstants.resolveMediaUrl(
        json['splashImageUrl'] as String?,
      ),
      logoImageUrl: ApiConstants.resolveMediaUrl(
        json['logoImageUrl'] as String?,
      ),
    );
  }

  factory BrandingConfig.defaults() => const BrandingConfig(
        splashImageUrl: null,
        logoImageUrl: null,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'splashImageUrl': splashImageUrl,
        'logoImageUrl': logoImageUrl,
      };
}
