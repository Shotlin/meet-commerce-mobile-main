import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/constants/app_constants.dart';
import 'package:bakaloo_flutter_app/core/constants/socket_events.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_event_handler.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_models/notification_event.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_models/order_status_event.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_models/refund_status_event.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_models/rider_location_event.dart';
import 'package:bakaloo_flutter_app/core/socket/socket_status.dart';

final socketServiceProvider = Provider<SocketService>((Ref ref) {
  final service = SocketService();
  ref.onDispose(service.dispose);
  return service;
});

class SocketService {
  SocketService();

  io.Socket? _socket;
  bool _listenersBound = false;
  final Map<String, Set<void Function(dynamic)>> _externalListeners =
      <String, Set<void Function(dynamic)>>{};

  // Order rooms the app has asked to track. Socket.IO room membership
  // doesn't survive a disconnect — a network blip, the OS suspending
  // the socket while backgrounded, or a token refresh all create a
  // brand-new server-side connection. Without replaying these joins
  // on every reconnect, a customer sitting on the live tracking
  // screen would silently stop receiving rider-location updates after
  // the first reconnect, with no error and no way to recover short of
  // leaving and re-entering the screen.
  final Set<String> _trackedOrderIds = <String>{};

  // ── Connection supervision ────────────────────────────────────────────
  // socket_io_client re-uses the `auth` token it was created with for every
  // automatic reconnect, and gives up after `socketReconnectAttempts`. The
  // access token only lives ~15 minutes, so a drop that outlasts it (phone
  // locked, app backgrounded, network switch) left the socket dead FOR GOOD
  // — status changes then only appeared after a manual refresh/reopen. This
  // supervisor keeps retrying forever with backoff, renewing credentials
  // (through the normal refresh-token path) before each attempt.
  Future<void> Function()? _refreshCredentials;
  Future<String?> Function()? _readAccessToken;
  Timer? _recoveryTimer;
  int _recoveryAttempt = 0;
  bool _stopped = true; // true until connect() / after disconnect()
  bool _disposed = false;

  /// Emits on EVERY successful (re)connect — consumers reconcile with REST,
  /// because events published while the socket was down are never replayed.
  final _connectedController = StreamController<void>.broadcast();
  Stream<void> get connectedStream => _connectedController.stream;

  final _orderStatusController = StreamController<OrderStatusEvent>.broadcast();
  final _refundStatusController =
      StreamController<RefundStatusEvent>.broadcast();
  final _riderLocationController =
      StreamController<RiderLocationEvent>.broadcast();
  final _notificationController =
      StreamController<NotificationEvent>.broadcast();
  final _themeUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _sectionUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _storeStatusUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _brandingUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<SocketStatus>.broadcast();

  Stream<OrderStatusEvent> get orderStatusStream =>
      _orderStatusController.stream;
  Stream<RefundStatusEvent> get refundStatusStream =>
      _refundStatusController.stream;
  Stream<RiderLocationEvent> get riderLocationStream =>
      _riderLocationController.stream;
  Stream<NotificationEvent> get notificationStream =>
      _notificationController.stream;
  Stream<Map<String, dynamic>> get themeUpdateStream =>
      _themeUpdateController.stream;
  Stream<Map<String, dynamic>> get sectionUpdateStream =>
      _sectionUpdateController.stream;
  Stream<Map<String, dynamic>> get storeStatusUpdateStream =>
      _storeStatusUpdateController.stream;
  Stream<Map<String, dynamic>> get brandingUpdateStream =>
      _brandingUpdateController.stream;
  Stream<SocketStatus> get statusStream => _statusController.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Wires credential renewal. [refreshCredentials] should perform one cheap
  /// authenticated request (a 401 there triggers the app's single, locked
  /// refresh-token flow, which calls [reconnect] with the new token);
  /// [readAccessToken] returns whatever token is currently stored.
  void configureRecovery({
    required Future<void> Function() refreshCredentials,
    required Future<String?> Function() readAccessToken,
  }) {
    _refreshCredentials = refreshCredentials;
    _readAccessToken = readAccessToken;
  }

  /// Called when the app returns to the foreground: if the socket is not
  /// connected, recover immediately (no backoff).
  void ensureConnected() {
    if (_disposed || _stopped || isConnected) return;
    _recoveryTimer?.cancel();
    unawaited(_recover());
  }

  void _scheduleRecovery() {
    if (_disposed || _stopped) return;
    _recoveryTimer?.cancel();
    // 2s, 4s, 8s, 16s, then every 30s — forever, until connected.
    final seconds = _recoveryAttempt >= 4 ? 30 : (2 << _recoveryAttempt);
    _recoveryAttempt++;
    _recoveryTimer = Timer(Duration(seconds: seconds), () {
      unawaited(_recover());
    });
  }

  Future<void> _recover() async {
    if (_disposed || _stopped || isConnected) return;
    try {
      await _refreshCredentials?.call();
    } catch (_) {
      // Offline etc. — the retry below will try again.
    }
    if (_disposed || _stopped || isConnected) return;
    String? token;
    try {
      token = await _readAccessToken?.call();
    } catch (_) {}
    if (token != null && token.trim().isNotEmpty) {
      reconnect(token);
    }
    _scheduleRecovery();
  }

  void connect(String accessToken) {
    if (accessToken.trim().isEmpty) {
      return;
    }
    _stopped = false;

    final socketUrl = ApiConstants.socketUrl;
    if (socketUrl.trim().isEmpty) {
      return;
    }

    _statusController.add(SocketStatus.connecting);
    _disposeSocketOnly();

    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(<String>['websocket'])
          .setAuth(<String, dynamic>{'token': accessToken})
          .enableAutoConnect()
          .setReconnectionAttempts(AppConstants.socketReconnectAttempts)
          .setReconnectionDelay(AppConstants.socketReconnectDelayMs)
          .build(),
    );

    _socket!
      ..onConnect((_) {
        _recoveryTimer?.cancel();
        _recoveryAttempt = 0;
        _statusController.add(SocketStatus.connected);
        _setupEventListeners();
        _replayTrackedOrders();
        _connectedController.add(null);
      })
      ..onDisconnect((reason) {
        _statusController.add(SocketStatus.disconnected);
        // 'io client disconnect' = we closed it on purpose (logout/reconnect).
        if (reason != 'io client disconnect') _scheduleRecovery();
      })
      ..onConnectError((_) {
        _statusController.add(SocketStatus.error);
        _scheduleRecovery();
      })
      ..onError((_) {
        _statusController.add(SocketStatus.error);
      });
  }

  void _setupEventListeners() {
    final socket = _socket;
    if (socket == null) {
      return;
    }

    if (_listenersBound) {
      socket
        ..off(SocketEvents.orderStatus)
        ..off(SocketEvents.refundStatus)
        ..off(SocketEvents.riderLocationUpdate)
        ..off(SocketEvents.notification)
        ..off(SocketEvents.themeUpdate)
        ..off(SocketEvents.sectionUpdate)
        ..off(SocketEvents.storeStatusUpdate)
        ..off(SocketEvents.brandingUpdate);
      for (final event in _externalListeners.keys) {
        socket.off(event);
      }
    }

    final eventHandler = SocketEventHandler(
      onOrderStatus: _orderStatusController.add,
      onRiderLocation: _riderLocationController.add,
      onNotification: _notificationController.add,
      onRefundStatus: _refundStatusController.add,
    );

    socket
      ..on(
        SocketEvents.orderStatus,
        (dynamic data) => eventHandler.route(SocketEvents.orderStatus, data),
      )
      ..on(
        SocketEvents.refundStatus,
        (dynamic data) => eventHandler.route(SocketEvents.refundStatus, data),
      )
      ..on(
        SocketEvents.riderLocationUpdate,
        (dynamic data) =>
            eventHandler.route(SocketEvents.riderLocationUpdate, data),
      )
      ..on(
        SocketEvents.notification,
        (dynamic data) => eventHandler.route(SocketEvents.notification, data),
      )
      ..on(SocketEvents.themeUpdate, (dynamic data) {
        final payload = _toJson(data);
        if (payload != null) {
          _themeUpdateController.add(payload);
        }
      })
      ..on(SocketEvents.sectionUpdate, (dynamic data) {
        final payload = _toJson(data);
        if (payload != null) {
          _sectionUpdateController.add(payload);
        }
      })
      ..on(SocketEvents.storeStatusUpdate, (dynamic data) {
        final payload = _toJson(data);
        if (payload != null) {
          _storeStatusUpdateController.add(payload);
        }
      })
      ..on(SocketEvents.brandingUpdate, (dynamic data) {
        final payload = _toJson(data);
        if (payload != null) {
          _brandingUpdateController.add(payload);
        }
      });

    _bindExternalListeners(socket);
    _listenersBound = true;
  }

  void on(String event, void Function(dynamic) handler) {
    final listeners = _externalListeners.putIfAbsent(
      event,
      () => <void Function(dynamic)>{},
    );
    if (!listeners.add(handler)) {
      return;
    }
    _socket?.on(event, handler);
  }

  void off(String event, [void Function(dynamic)? handler]) {
    final socket = _socket;
    if (handler == null) {
      _externalListeners.remove(event);
      socket?.off(event);
      return;
    }

    final listeners = _externalListeners[event];
    listeners?.remove(handler);
    if (listeners != null && listeners.isEmpty) {
      _externalListeners.remove(event);
    }
    socket?.off(event, handler);
  }

  void startTracking(String orderId) {
    final trimmed = orderId.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _trackedOrderIds.add(trimmed);
    _socket?.emit(SocketEvents.orderTrack, trimmed);
  }

  void stopTracking(String orderId) {
    final trimmed = orderId.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _trackedOrderIds.remove(trimmed);
    _socket?.emit(SocketEvents.orderUntrack, trimmed);
  }

  /// Re-joins every order room the app is currently tracking. Called
  /// on every `connect` event (initial connect AND every reconnect)
  /// so room membership — which Socket.IO ties to the connection, not
  /// the user — survives transparently across drops.
  void _replayTrackedOrders() {
    for (final orderId in _trackedOrderIds) {
      _socket?.emit(SocketEvents.orderTrack, orderId);
    }
  }

  void reconnect(String newToken) {
    final token = newToken.trim();
    if (token.isEmpty) {
      return;
    }

    final socket = _socket;
    if (socket == null) {
      connect(token);
      return;
    }

    socket
      ..auth = <String, dynamic>{'token': token}
      ..disconnect()
      ..connect();
  }

  void disconnect() {
    _stopped = true;
    _recoveryTimer?.cancel();
    _recoveryAttempt = 0;
    _disposeSocketOnly();
    _trackedOrderIds.clear();
    _statusController.add(SocketStatus.disconnected);
  }

  void dispose() {
    _disposed = true;
    _recoveryTimer?.cancel();
    _disposeSocketOnly();
    _connectedController.close();
    _refundStatusController.close();
    _orderStatusController.close();
    _riderLocationController.close();
    _notificationController.close();
    _themeUpdateController.close();
    _sectionUpdateController.close();
    _storeStatusUpdateController.close();
    _brandingUpdateController.close();
    _statusController.close();
  }

  void _disposeSocketOnly() {
    _socket?.dispose();
    _socket = null;
    _listenersBound = false;
  }

  void _bindExternalListeners(io.Socket socket) {
    for (final entry in _externalListeners.entries) {
      for (final listener in entry.value) {
        socket.on(entry.key, listener);
      }
    }
  }

  Map<String, dynamic>? _toJson(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    if (payload is String && payload.trim().isNotEmpty) {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }
    return null;
  }
}
