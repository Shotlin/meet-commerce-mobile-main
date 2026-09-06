import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/network/network_monitor.dart';
import 'package:bakaloo_flutter_app/shared/providers/connectivity_provider.dart';

enum AppAvailabilityStatus {
  online,
  offline,
  serviceUnavailable,
}

class AppAvailabilityNotifier extends Notifier<AppAvailabilityStatus> {
  bool _browsingWhileOffline = false;

  // PHASE 3 FIX: Count consecutive service failures. A SINGLE timeout on
  // mobile data must NOT flip the whole app to the red "Service unavailable"
  // blocker — that is the main cause of the stale/old-UI report. We only
  // escalate to the blocker after repeated failures, and we always recover
  // automatically when any request succeeds or connectivity changes.
  //
  // PHASE 3b FIX: Parallel requests on the same page-load (theme + products +
  // banners firing simultaneously) were all hitting the counter at once and
  // reaching the threshold of 3 within a single burst. The fix uses a
  // debounce window: multiple failures within [_failureWindowMs] are collapsed
  // into a single logical failure increment, so one bad page-load counts as 1
  // not 3+. Threshold raised to 5 for extra safety.
  int _consecutiveServiceFailures = 0;
  static const int _serviceUnavailableThreshold = 5;
  static const int _failureWindowMs = 2000; // collapse rapid bursts
  DateTime? _lastFailureTime;

  @override
  AppAvailabilityStatus build() {
    final initialStatus = ref.watch(connectivityStatusProvider);

    ref.listen<AsyncValue<ConnectivityStatus>>(connectivityStatusProvider, (
      _,
      next,
    ) {
      next.whenData(syncConnectivity);
    });

    return initialStatus.maybeWhen(
      data: (ConnectivityStatus value) => value == ConnectivityStatus.offline
          ? AppAvailabilityStatus.offline
          : AppAvailabilityStatus.online,
      orElse: () => AppAvailabilityStatus.online,
    );
  }

  void syncConnectivity(ConnectivityStatus status) {
    if (status == ConnectivityStatus.offline) {
      // Respect a user who chose "Browse saved items" — don't re-block them.
      if (_browsingWhileOffline) {
        return;
      }
      state = AppAvailabilityStatus.offline;
      return;
    }

    // PHASE 3 FIX: Genuine connectivity change (e.g. WiFi → mobile data).
    // Reset ALL stale failure state and run a fresh health check rather than
    // keeping the old service-unavailable blocker. This is what makes the app
    // recover automatically when the user switches networks.
    _browsingWhileOffline = false;
    _consecutiveServiceFailures = 0;
    _lastFailureTime = null;
    state = AppAvailabilityStatus.online;
    // Verify reachability in the background; only re-block if it truly fails.
    unawaited(_revalidate());
  }

  void reportOffline() {
    if (_browsingWhileOffline) {
      return;
    }
    state = AppAvailabilityStatus.offline;
  }

  /// PHASE 3 FIX: A single failed request increments a counter instead of
  /// immediately blocking the whole app. Only after [_serviceUnavailableThreshold]
  /// consecutive failures do we show the full-screen blocker. This prevents a
  /// transient mobile-data timeout from swapping the app to the red screen.
  ///
  /// PHASE 3b FIX: Multiple parallel failures within [_failureWindowMs] (e.g.
  /// theme + products + banners all failing at once on a cold start) are
  /// collapsed into a single increment so a burst of concurrent failures from
  /// one page-load counts as ONE failure, not N failures.
  void reportServiceUnavailable() {
    final now = DateTime.now();
    final last = _lastFailureTime;
    if (last != null &&
        now.difference(last).inMilliseconds < _failureWindowMs) {
      // Same burst window — don't increment again.
      return;
    }
    _lastFailureTime = now;
    _consecutiveServiceFailures++;
    if (_consecutiveServiceFailures < _serviceUnavailableThreshold) {
      return;
    }
    if (state != AppAvailabilityStatus.offline) {
      state = AppAvailabilityStatus.serviceUnavailable;
    }
  }

  void reportHealthy() {
    // PHASE 3 FIX: Any successful response immediately clears the failure
    // counter and the blocker so the app recovers the moment the backend
    // responds again.
    _consecutiveServiceFailures = 0;
    _lastFailureTime = null;
    if (state != AppAvailabilityStatus.offline) {
      state = AppAvailabilityStatus.online;
    }
  }

  /// Re-checks live connectivity and clears the blocker when reachable.
  /// Used by the offline screen's "Retry" button.
  Future<void> retry() async {
    _browsingWhileOffline = false;

    final connected = await ref.read(networkMonitorProvider).isConnected;
    if (!connected) {
      state = AppAvailabilityStatus.offline;
      return;
    }

    _consecutiveServiceFailures = 0;
    _lastFailureTime = null;
    state = AppAvailabilityStatus.online;
  }

  /// PHASE 3 FIX: Background revalidation after a network change. Checks the
  /// OS connectivity; if connected, optimistically clears the blocker. The
  /// next real API response (success → reportHealthy, repeated failures →
  /// reportServiceUnavailable) confirms the final state.
  Future<void> _revalidate() async {
    final connected = await ref.read(networkMonitorProvider).isConnected;
    if (!connected) {
      if (!_browsingWhileOffline) {
        state = AppAvailabilityStatus.offline;
      }
      return;
    }
    _consecutiveServiceFailures = 0;
    _lastFailureTime = null;
    if (state != AppAvailabilityStatus.offline) {
      state = AppAvailabilityStatus.online;
    }
  }

  /// Dismisses the offline blocker so the user can browse cached/saved
  /// content. The blocker re-appears on the next failed request unless
  /// connectivity is genuinely restored.
  void browseOffline() {
    _browsingWhileOffline = true;
    state = AppAvailabilityStatus.online;
  }
}

final appAvailabilityProvider =
    NotifierProvider<AppAvailabilityNotifier, AppAvailabilityStatus>(
  AppAvailabilityNotifier.new,
);
