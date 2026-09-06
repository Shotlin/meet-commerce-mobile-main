import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/network/network_monitor.dart';

final networkMonitorProvider = Provider<NetworkMonitor>((Ref ref) {
  return NetworkMonitor();
});

final connectivityStatusProvider =
    StreamProvider<ConnectivityStatus>((Ref ref) {
  final monitor = ref.watch(networkMonitorProvider);
  return monitor.watchStatus();
});

final isOnlineProvider = Provider<bool>((Ref ref) {
  final status = ref.watch(connectivityStatusProvider);
  return status.maybeWhen(
    data: (ConnectivityStatus value) => value == ConnectivityStatus.online,
    orElse: () => true,
  );
});
