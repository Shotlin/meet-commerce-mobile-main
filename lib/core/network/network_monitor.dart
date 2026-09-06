import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectivityStatus {
  online,
  offline,
}

class NetworkMonitor {
  NetworkMonitor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return _toStatus(results) == ConnectivityStatus.online;
  }

  Stream<ConnectivityStatus> watchStatus() {
    return _connectivity.onConnectivityChanged.map(_toStatus).distinct();
  }

  ConnectivityStatus _toStatus(List<ConnectivityResult> results) {
    if (results.isEmpty ||
        results.every((result) => result == ConnectivityResult.none)) {
      return ConnectivityStatus.offline;
    }

    return ConnectivityStatus.online;
  }
}
