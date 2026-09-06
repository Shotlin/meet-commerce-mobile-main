import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bakaloo_flutter_app/core/constants/storage_keys.dart';

/// Whether the customer's most recently auto-detected location (via "Use my
/// current location") landed outside every shop's service area. The backend
/// hard-blocks saving an Address for such a location (see
/// bakaloo-backend/src/modules/addresses/addresses.service.js,
/// ADDRESS_NOT_SERVICEABLE) — so there's no saved address to check against
/// later. This flag is the only record that detection ever happened, kept
/// around so the cart can show "Your area is not serviceable" instead of
/// its normal "Add Address to Proceed" CTA, rather than looking identical
/// to a customer who never engaged with location at all.
///
/// Deliberately never actively cleared: once the customer has any real
/// saved address (which the backend gate guarantees is serviceable), the
/// cart stops reading this flag entirely (see cart_screen.dart's
/// `hasAddress` guard) — a stale `true` left over from an earlier detection
/// is simply inert at that point, so there's nothing to clean up.
class NonServiceableLocationNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    state = preferences.getBool(StorageKeys.nonServiceableLocationDetected) ??
        false;
  }

  Future<void> markDetected() async {
    state = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(StorageKeys.nonServiceableLocationDetected, true);
  }
}

final nonServiceableLocationProvider =
    NotifierProvider<NonServiceableLocationNotifier, bool>(
  NonServiceableLocationNotifier.new,
);
