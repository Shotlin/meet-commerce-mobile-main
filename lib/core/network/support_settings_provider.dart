import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';

part 'support_settings_provider.g.dart';

/// Brand name / support phone / support email — the single source of
/// truth every "Need Help" (Order Details) / "Contact Us" (Profile)
/// surface reads from, replacing the old hardcoded
/// AppConstants.supportPhone/supportEmail. `supportPhone`/`supportEmail`
/// are genuinely `null` when an admin hasn't configured one yet — callers
/// must hide that row rather than render something broken, never invent a
/// fallback number/address.
class SupportContact {
  const SupportContact({
    required this.brandName,
    this.supportPhone,
    this.supportEmail,
  });

  static const SupportContact empty = SupportContact(brandName: 'FreshCuts');

  final String brandName;
  final String? supportPhone;
  final String? supportEmail;

  /// Dialable form — strips everything but digits and a leading `+`, since
  /// the dashboard-entered number may contain spaces for readability
  /// (e.g. "+91 99249 98906") that `tel:` URIs don't need.
  String? get supportPhoneDialable {
    final phone = supportPhone;
    if (phone == null || phone.trim().isEmpty) return null;
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    return cleaned.isEmpty ? null : cleaned;
  }
}

/// Fetched fresh every time something watches this (default `@riverpod`
/// autoDispose — the provider is torn down once the last watcher, i.e. the
/// bottom sheet, is closed), so a dashboard change is visible the very
/// next time a customer opens "Need Help"/"Contact Us", without any
/// explicit cache-busting logic needed. A bare, short-timeout client
/// exactly like `app_version_provider.dart`'s own pattern — this must
/// never block or visibly fail the sheet on a network hiccup, so it fails
/// open to [SupportContact.empty] (title-only sheet, phone/email rows
/// hidden) rather than showing an error.
@riverpod
Future<SupportContact> supportContact(Ref ref) async {
  try {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );

    final response = await dio.get<dynamic>(ApiConstants.supportSettings);

    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)['data']
        : null;
    if (data is! Map) {
      return SupportContact.empty;
    }
    final payload = Map<String, dynamic>.from(data);

    final brandName = (payload['brandName'] as String?)?.trim();
    final phone = (payload['supportPhone'] as String?)?.trim();
    final email = (payload['supportEmail'] as String?)?.trim();

    return SupportContact(
      brandName: brandName?.isNotEmpty == true ? brandName! : 'FreshCuts',
      supportPhone: phone?.isNotEmpty == true ? phone : null,
      supportEmail: email?.isNotEmpty == true ? email : null,
    );
  } catch (_) {
    return SupportContact.empty;
  }
}
