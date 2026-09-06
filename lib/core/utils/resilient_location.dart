import 'package:geolocator/geolocator.dart';

/// Attempts to get the device's current position with a resilient, tiered
/// fallback instead of one unguarded `getCurrentPosition()` call.
///
/// Reported bug: right after a customer turns location on from Settings
/// and comes back to the app, a single medium/high-accuracy attempt
/// regularly failed (or, worse, hung indefinitely when no `timeLimit` was
/// set at all) — the OS's location subsystem hasn't warmed back up yet (no
/// recent GPS fix, network-location provider not yet re-initialized), so
/// GPS-grade accuracy often isn't available in time, especially indoors.
///
/// Order of attempts:
///   1. The OS's cached last-known position — near-instant, no GPS
///      engagement, and accurate enough for a delivery address (the
///      customer still confirms/adjusts the pin afterward anyway).
///   2. A fast, low-accuracy fix (network/cell-tower based) — usually only
///      a few seconds even on a cold start.
///   3. A longer medium-accuracy fix, only if the fast attempt failed.
///   4. One final cached-position re-check, in case the OS picked up
///      *something* in the background across attempts 2-3 even though
///      neither returned a fix directly.
///
/// If every attempt fails, rethrows the error from the medium-accuracy
/// attempt (step 3) with its original stack trace, so callers can catch
/// and report it exactly as they would a plain `getCurrentPosition()`
/// call — no call site needs to change its existing catch-block logic.
Future<Position> getResilientCurrentPosition() async {
  final cached = await Geolocator.getLastKnownPosition();
  if (cached != null) {
    return cached;
  }

  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 12),
      ),
    );
  } catch (_) {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (err, stack) {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return lastKnown;
      }
      Error.throwWithStackTrace(err, stack);
    }
  }
}
