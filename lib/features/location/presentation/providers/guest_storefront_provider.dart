import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';
import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/core/maps/device_pincodes.dart';
import 'package:bakaloo_flutter_app/core/maps/geo_point.dart';
import 'package:bakaloo_flutter_app/core/maps/ola/ola_maps_service.dart';
import 'package:bakaloo_flutter_app/core/maps/storefront_resolver.dart';
import 'package:bakaloo_flutter_app/core/storage/app_cache_manager.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/core/utils/pincode.dart';
import 'package:bakaloo_flutter_app/core/utils/resilient_location.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';

enum GuestStorefrontStatus {
  loading,
  unresolved,
  resolving,
  serviceable,
  unavailable,
  failed
}

const String _guestStorefrontSecureCacheKey =
    'guest_storefront_location_cache_v1';

const FlutterSecureStorage _guestStorefrontSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

class GuestStorefrontState {
  const GuestStorefrontState({
    required this.status,
    this.token,
    this.shopId,
    this.shopName,
    this.pincode,
    this.addressLine1,
    this.city,
    this.stateName,
    this.lat,
    this.lng,
    this.message,
  });

  const GuestStorefrontState.loading()
      : this(status: GuestStorefrontStatus.loading);
  const GuestStorefrontState.unresolved()
      : this(status: GuestStorefrontStatus.unresolved);

  final GuestStorefrontStatus status;
  final String? token;
  final String? shopId;
  final String? shopName;
  final String? pincode;
  final String? addressLine1;
  final String? city;
  final String? stateName;
  final double? lat;
  final double? lng;
  final String? message;

  bool get isReady =>
      status == GuestStorefrontStatus.serviceable && token != null;
}

class GuestStorefrontNotifier extends Notifier<GuestStorefrontState> {
  @override
  GuestStorefrontState build() {
    unawaited(_load());
    return const GuestStorefrontState.loading();
  }

  Future<void> _load() async {
    try {
      final raw = await _readGuestStorefrontCache();
      if (raw is Map) {
        final expiresAt = DateTime.tryParse(raw['expiresAt'] as String? ?? '');
        if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) {
          await HiveService.settingsBox
              .delete(StorageKeys.guestStorefrontLocation);
          await _guestStorefrontSecureStorage.delete(
            key: _guestStorefrontSecureCacheKey,
          );
          state = const GuestStorefrontState.unresolved();
          return;
        }
        final token = raw['token'];
        final shopId = raw['shopId'];
        if (token is String &&
            token.isNotEmpty &&
            shopId is String &&
            shopId.isNotEmpty) {
          final GuestStorefrontState restored = GuestStorefrontState(
            status: GuestStorefrontStatus.serviceable,
            token: token,
            shopId: shopId,
            shopName: raw['shopName'] as String?,
            pincode: raw['pincode'] as String?,
            addressLine1: raw['addressLine1'] as String?,
            city: raw['city'] as String?,
            stateName: raw['state'] as String?,
            lat: (raw['lat'] as num?)?.toDouble(),
            lng: (raw['lng'] as num?)?.toDouble(),
          );
          // The storefront scope owns the theme/product cache keys.  Set it
          // before exposing a ready guest location so Home cannot request a
          // theme with the previous (anonymous or another-shop) scope.
          await AppCacheManager.setShopScope([shopId]);
          state = restored;
          return;
        }
      }
      state = const GuestStorefrontState.unresolved();
    } catch (_) {
      // Never leave the startup gate in its loading state if local storage is
      // temporarily unavailable. The gate can then show one actionable
      // location prompt instead of an indefinite skeleton.
      state = const GuestStorefrontState(
        status: GuestStorefrontStatus.failed,
        message: 'Could not restore your delivery location.',
      );
    }
  }

  /// Keeps the seven-day guest storefront local to this device. Hive remains
  /// the primary cache; encrypted secure storage is a durable fallback if a
  /// Hive box is rotated or repaired during an app update.
  Future<Map<dynamic, dynamic>?> _readGuestStorefrontCache() async {
    try {
      final hiveValue =
          HiveService.settingsBox.get(StorageKeys.guestStorefrontLocation);
      if (hiveValue is Map) return hiveValue;
    } catch (_) {
      // Try the encrypted backup below.
    }

    try {
      final encoded = await _guestStorefrontSecureStorage.read(
        key: _guestStorefrontSecureCacheKey,
      );
      if (encoded == null || encoded.isEmpty) return null;
      final decoded = jsonDecode(encoded);
      return decoded is Map ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> resolveCurrentLocation() async {
    if (state.status == GuestStorefrontStatus.resolving) return;
    state = const GuestStorefrontState(status: GuestStorefrontStatus.resolving);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        state = const GuestStorefrontState(
            status: GuestStorefrontStatus.failed,
            message: 'Turn on location services to continue.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        state = const GuestStorefrontState(
            status: GuestStorefrontStatus.failed,
            message: 'Location permission is required to show your store.');
        return;
      }
      final position = await getResilientCurrentPosition();
      // Ask BOTH geocoders in parallel. Ola (signed-in users only — a guest has
      // no token yet, so it just yields null) and the phone's own geocoder can
      // report different PINs for the same spot, and a shop set to "match by
      // PIN only" is served by an exact PIN match at any distance. Every
      // distinct, normalised PIN is tried, best source first, until one is
      // served (see resolveStorefront).
      final geoPoint = GeoPoint(lat: position.latitude, lng: position.longitude);
      final geocoded = await Future.wait<Object?>(<Future<Object?>>[
        ref.read(olaMapsServiceProvider).reverseGeocode(geoPoint),
        reverseGeocodeOnDevice(position.latitude, position.longitude),
      ]);
      final reverse = geocoded[0] as ReverseGeocodeResult?;
      final devicePlacemarks = geocoded[1] as List<DevicePlacemarkInfo>;
      final nativePlacemark =
          devicePlacemarks.isEmpty ? null : devicePlacemarks.first;
      final resolvedCity = reverse?.city?.trim().isNotEmpty == true
          ? reverse!.city!.trim()
          : nativePlacemark?.locality;
      final candidatePins = dedupePincodes(<String?>[
        reverse?.pincode,
        ...pincodesOf(devicePlacemarks),
      ]);

      final resolution = await resolveStorefront(
        lat: position.latitude,
        lng: position.longitude,
        candidates: candidatePins,
        call: (payload) async {
          final response = await ref
              .read(dioClientProvider)
              .post<dynamic>(ApiConstants.storefrontResolveLocation,
                  data: payload);
          final body = response.data is Map
              ? Map<String, dynamic>.from(response.data as Map)
              : const <String, dynamic>{};
          return body['data'] is Map
              ? Map<String, dynamic>.from(body['data'] as Map)
              : const <String, dynamic>{};
        },
      );
      // The PIN that actually matched a shop (else the first one tried), so
      // the address prefilled after sign-in agrees with the serviceability
      // decision.
      final pincode = resolution.pincode ?? '';
      final data = resolution.data;
      if (data['serviceable'] != true) {
        state = GuestStorefrontState(
          status: GuestStorefrontStatus.unavailable,
          pincode: pincode.isEmpty ? null : pincode,
          city: resolvedCity?.isNotEmpty == true ? resolvedCity : null,
          addressLine1: reverse?.addressLine1 ?? reverse?.displayName,
          message: 'Delivery is not available at this location yet.',
        );
        return;
      }
      final token = data['storefrontToken'] as String?;
      final shop = data['shop'] is Map
          ? Map<String, dynamic>.from(data['shop'] as Map)
          : const <String, dynamic>{};
      final shopId = shop['id'] as String?;
      if (token == null || token.isEmpty || shopId == null || shopId.isEmpty)
        throw StateError('Invalid storefront response');
      final next = GuestStorefrontState(
        status: GuestStorefrontStatus.serviceable,
        token: token,
        shopId: shopId,
        shopName: shop['name'] as String?,
        pincode: pincode,
        lat: position.latitude,
        lng: position.longitude,
        addressLine1:
            reverse?.addressLine1 ?? reverse?.displayName ?? 'My Location',
        city: resolvedCity?.isNotEmpty == true ? resolvedCity : 'Local Area',
        stateName: reverse?.state ?? nativePlacemark?.administrativeArea ?? '',
      );
      final cacheRecord = <String, dynamic>{
        'token': token,
        'shopId': shopId,
        'shopName': next.shopName,
        'pincode': pincode,
        'lat': position.latitude,
        'lng': position.longitude,
        'addressLine1': next.addressLine1,
        'city': next.city,
        'state': next.stateName,
        // Guest location is device-local only. Keep the signed storefront for
        // seven days so app relaunches do not repeat geolocation/API calls.
        'expiresAt':
            DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      };
      await Future.wait<void>([
        HiveService.settingsBox
            .put(StorageKeys.guestStorefrontLocation, cacheRecord),
        _guestStorefrontSecureStorage.write(
          key: _guestStorefrontSecureCacheKey,
          value: jsonEncode(cacheRecord),
        ),
      ]);
      await AppCacheManager.setShopScope([shopId]);
      await _saveLocationToAuthenticatedAccount(next);
      state = next;
    } on DioException {
      state = const GuestStorefrontState(
          status: GuestStorefrontStatus.failed,
          message:
              'Could not verify your delivery location. Please try again.');
    } catch (_) {
      state = const GuestStorefrontState(
          status: GuestStorefrontStatus.failed,
          message:
              'Could not verify your delivery location. Please try again.');
    }
  }

  Future<void> _saveLocationToAuthenticatedAccount(
    GuestStorefrontState location,
  ) async {
    if (ref.read(authStateProvider) is! AuthAuthenticated) return;

    final dio = ref.read(dioClientProvider);
    final existing = await dio.get<dynamic>(ApiConstants.addresses);
    final existingData = existing.data is Map ? existing.data['data'] : null;
    if (existingData is List && existingData.isNotEmpty) return;

    await dio.post<dynamic>(ApiConstants.addresses, data: <String, dynamic>{
      'label': 'Home',
      'addressLine1': location.addressLine1 ?? 'My Location',
      'city': location.city ?? '',
      'state': location.stateName ?? '',
      'pincode': location.pincode,
      'lat': location.lat,
      'lng': location.lng,
      'isDefault': true,
    });
    ref.invalidate(addressProvider);
  }
}

final guestStorefrontProvider =
    NotifierProvider<GuestStorefrontNotifier, GuestStorefrontState>(
        GuestStorefrontNotifier.new);

/// Signed guest location is required only before login. A signed-in customer
/// is resolved from saved-address allocations by the backend.
final storefrontAccessProvider = FutureProvider<bool>((ref) async {
  if (ref.watch(authStateProvider) is! AuthAuthenticated) {
    return ref.watch(guestStorefrontProvider).isReady;
  }

  // An older account with no saved delivery address must choose a location
  // before any catalogue endpoint is allowed to run.
  final addresses = await ref.watch(addressProvider.future);
  return addresses.isNotEmpty;
});

final storefrontReadyProvider = Provider<bool>((ref) {
  // A guest storefront is already completely resolved by the signed location
  // token.  Do not put that synchronous state behind an AsyncValue: Home's
  // product providers can otherwise run once while that FutureProvider is
  // loading, cache an empty list, and leave the product rails blank.
  if (ref.watch(authStateProvider) is! AuthAuthenticated) {
    return ref.watch(guestStorefrontProvider).isReady;
  }
  return ref.watch(storefrontAccessProvider).value == true;
});
