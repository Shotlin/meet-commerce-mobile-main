import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bakaloo_flutter_app/core/errors/failure.dart';
import 'package:bakaloo_flutter_app/core/network/connectivity_interceptor.dart';
import 'package:bakaloo_flutter_app/core/network/network_monitor.dart';

/// A real request never actually completed transport-level tests for this
/// interceptor need only prove whether it reached the (fake) network at
/// all — a scripted 200 stand-in, same idiom as refresh_interceptor_test.
class _ScriptedOkAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}

/// Returns a scripted, pre-set sequence of `isConnected` results — the
/// real bug this guards against is `connectivity_plus` reporting a single
/// transient `false` right as a request fires, even though the device (and,
/// separately confirmed, the backend) were genuinely reachable a moment
/// later.
class _SequencedNetworkMonitor extends NetworkMonitor {
  _SequencedNetworkMonitor(this._results);

  final List<bool> _results;
  int _index = 0;

  @override
  Future<bool> get isConnected async {
    final value = _index < _results.length ? _results[_index] : _results.last;
    _index++;
    return value;
  }
}

Dio _buildDio(NetworkMonitor monitor, {VoidCallback? onOffline}) {
  return Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = _ScriptedOkAdapter()
    ..interceptors.add(ConnectivityInterceptor(monitor, onOfflineDetected: onOffline));
}

void main() {
  test('passes the request through immediately when the first connectivity check is online', () async {
    final dio = _buildDio(_SequencedNetworkMonitor(<bool>[true]));

    final response = await dio.get<dynamic>('/ping');

    expect(response.statusCode, 200);
  });

  test(
    'tolerates a single transient "offline" reading — re-checks once before ever rejecting a real request',
    () async {
      final dio = _buildDio(_SequencedNetworkMonitor(<bool>[false, true]));

      final response = await dio.get<dynamic>('/ping');

      expect(response.statusCode, 200);
    },
  );

  test(
    'only rejects (and notifies onOfflineDetected) when BOTH the first check and the re-check say offline',
    () async {
      var offlineDetected = false;
      final dio = _buildDio(
        _SequencedNetworkMonitor(<bool>[false, false]),
        onOffline: () => offlineDetected = true,
      );

      await expectLater(
        dio.get<dynamic>('/ping'),
        throwsA(
          isA<DioException>().having(
            (DioException e) => e.error,
            'error',
            // Wrapped in a real Failure (not a raw string) so
            // handleDioError's `case final Failure failure` shortcut
            // returns it directly, never conflating a genuinely-offline
            // device with a request that was attempted and failed
            // downstream (error_handler.dart's connectionError case).
            isA<NetworkFailure>(),
          ),
        ),
      );
      expect(offlineDetected, isTrue);
    },
  );
}
