import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/notifications/fcm_token_helper.dart';
import 'package:bakaloo_flutter_app/core/notifications/local_notification_service.dart';
import 'package:bakaloo_flutter_app/core/notifications/notification_navigation.dart';
import 'package:bakaloo_flutter_app/core/notifications/notification_router.dart';
import 'package:bakaloo_flutter_app/core/session/session_ready_gate.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bakaloo_flutter_app/features/auth/presentation/providers/auth_state.dart';
import 'package:bakaloo_flutter_app/features/notifications/presentation/providers/notification_provider.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_live_sync_provider.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:bakaloo_flutter_app/routing/app_router.dart';

part 'fcm_service.g.dart';

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  Ref ref,
) {
  return LocalNotificationService();
});

@Riverpod(keepAlive: true)
FCMService fcmService(Ref ref) {
  final service = FCMService(
    localNotifications: ref.watch(localNotificationServiceProvider),
    router: ref.watch(appRouterProvider),
    sessionReadyGate: ref.watch(sessionReadyGateProvider),
  );
  ref.onDispose(service.dispose);
  return service;
}

String _platformNameFor(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    TargetPlatform.macOS => 'ios',
    TargetPlatform.windows => 'android',
    TargetPlatform.linux => 'android',
    TargetPlatform.fuchsia => 'android',
  };
}

@Riverpod(keepAlive: true)
Future<void> initializeFcm(Ref ref) async {
  await ref.watch(fcmServiceProvider).init();

  // The login flow (auth_notifier.dart) registers the FCM token once, right
  // after a fresh OTP verification — but that alone misses two real cases:
  // a persisted session that skips the login screen entirely on this
  // launch, and a token that rotates later in the session (reinstall, OS
  // token refresh). Previously neither ever reached the backend — the
  // token-refresh callback below was wired up but never invoked, so a
  // rotated token was captured and silently dropped forever. Both gaps hit
  // iOS hardest, since APNs-backed tokens rotate more readily than
  // Android's, and the backend only keeps one active token per user — a
  // stale token silently blocks all delivery to the device that should be
  // active.
  Future<void> registerToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return;
    try {
      await ref.read(registerFcmTokenUseCaseProvider).call(
            token: trimmed,
            platform: _platformNameFor(defaultTargetPlatform),
          );
    } catch (err, stack) {
      // Previously swallowed with no trace at all — logging this (rather
      // than the message-app-must-not-crash requirement being an excuse to
      // go silent) is what would have surfaced this class of bug earlier.
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          err,
          stack,
          reason: 'FCM token registration failed',
          fatal: false,
        ),
      );
    }
  }

  ref.watch(fcmServiceProvider).setTokenRefreshCallback(registerToken);

  // Reports a tapped/opened campaign push to the backend so the admin
  // dashboard's "Opened" column reflects real taps instead of always
  // showing 0. Fire-and-forget: a failure here (offline, session expired
  // between receiving and tapping the push) must never block navigation.
  Future<void> reportCampaignOpened(String campaignId) async {
    try {
      await ref.read(markCampaignOpenedUseCaseProvider).call(campaignId);
    } catch (err, stack) {
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          err,
          stack,
          reason: 'markCampaignOpened failed',
          fatal: false,
        ),
      );
    }
  }

  ref.watch(fcmServiceProvider).setCampaignOpenedCallback(
        (campaignId) => unawaited(reportCampaignOpened(campaignId)),
      );

  // Admin credit, refund, cashback, topup-approved all arrive as a PAYMENT/
  // WALLET push (same types NotificationRouter.getPath already routes to
  // the wallet screen) — but a push alone never refetches the keepAlive
  // walletProvider, so the balance stayed stale until something else
  // happened to refresh it. Covers both the foreground (onMessage) and
  // tap/cold-start (_handleNotificationTap) delivery paths.
  ref.watch(fcmServiceProvider).setWalletRelatedMessageCallback(
        () => ref.invalidate(walletProvider),
      );

  // Order-status / refund pushes re-read that order (push-triggered sync).
  ref.watch(fcmServiceProvider).setOrderRelatedMessageCallback(
        (orderId, {required wallet}) => unawaited(
          ref
              .read(orderLiveSyncControllerProvider)
              .syncOrder(orderId, wallet: wallet),
        ),
      );

  ref.listen<AuthState>(
    authNotifierProvider,
    (previous, next) {
      if (next is! AuthAuthenticated) return;
      getFcmTokenAwaitingApns(FirebaseMessaging.instance).then((token) {
        if (token != null) unawaited(registerToken(token));
      }).catchError((Object err, StackTrace stack) {
        unawaited(
          FirebaseCrashlytics.instance.recordError(
            err,
            stack,
            reason: 'FCM getToken failed on auth-authenticated re-registration',
            fatal: false,
          ),
        );
      });
    },
    fireImmediately: true,
  );
}

class FCMService {
  FCMService({
    required LocalNotificationService localNotifications,
    required GoRouter router,
    required SessionReadyGate sessionReadyGate,
    FirebaseMessaging? messaging,
  })  : _localNotifications = localNotifications,
        _router = router,
        _sessionReadyGate = sessionReadyGate,
        _messaging = messaging ?? FirebaseMessaging.instance;

  final LocalNotificationService _localNotifications;
  final GoRouter _router;
  final SessionReadyGate _sessionReadyGate;
  final FirebaseMessaging _messaging;

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    await _localNotifications.initialize(onTap: _handleNotificationTap);
    await requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _subscriptions
      ..add(
        FirebaseMessaging.onMessage.listen((message) {
          unawaited(_localNotifications.show(message));
          _notifyIfWalletRelated(message.data);
          _notifyIfOrderRelated(message.data);
        }),
      )
      ..add(
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          _handleNotificationTap(message.data);
        }),
      )
      ..add(
        _messaging.onTokenRefresh.listen((newToken) {
          unawaited(_onTokenRefresh(newToken));
        }),
      );

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage.data);
    }

    _initialized = true;
  }

  Future<NotificationSettings> requestPermission({
    required bool alert,
    required bool badge,
    required bool sound,
  }) {
    return _messaging.requestPermission(
      alert: alert,
      badge: badge,
      sound: sound,
    );
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _initialized = false;
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final campaignId = data['campaignId'];
    if (campaignId is String && campaignId.isNotEmpty) {
      _campaignOpenedCallback?.call(campaignId);
    }
    _notifyIfWalletRelated(data);
    _notifyIfOrderRelated(data);

    final path = NotificationRouter.getPath(data);
    if (path == null || path.isEmpty) {
      return;
    }
    unawaited(_navigateOnceSessionReady(path));
  }

  // A cold start via `getInitialMessage()` can resolve before the splash
  // screen has restored the persisted session, which would otherwise send
  // an already-logged-in user to the login screen (see SessionReadyGate).
  // Once the gate is complete (the common case — app was already running),
  // this resolves on the next microtask with no visible delay.
  //
  // Uses navigateToNotificationTarget rather than a bare `_router.go(path)`
  // — see notification_navigation.dart for why: go() alone replaces the
  // whole stack, and for a target outside the bottom-nav shell (Cart,
  // Product Detail, Search, …) that leaves nothing beneath it, so the very
  // first back-press exits the app instead of returning into it.
  Future<void> _navigateOnceSessionReady(String path) async {
    await _sessionReadyGate.ready;
    navigateToNotificationTarget(path, go: _router.go, push: _router.push);
  }

  Future<void> _onTokenRefresh(String newToken) async {
    // Token refreshed — re-register with backend
    // We use a delayed registration via a callback if set, otherwise log
    _pendingRefreshToken = newToken;
    _tokenRefreshCallback?.call(newToken);
  }

  String? _pendingRefreshToken;
  void Function(String token)? _tokenRefreshCallback;

  /// Called by the notification notifier after login to register the token.
  void setTokenRefreshCallback(void Function(String token) callback) {
    _tokenRefreshCallback = callback;
    // If a token refresh happened before callback was set, fire it now
    if (_pendingRefreshToken != null) {
      callback(_pendingRefreshToken!);
      _pendingRefreshToken = null;
    }
  }

  void Function(String campaignId)? _campaignOpenedCallback;

  /// Called whenever a push notification carrying a `campaignId` is
  /// tapped (foreground, background, or cold start).
  void setCampaignOpenedCallback(void Function(String campaignId) callback) {
    _campaignOpenedCallback = callback;
  }

  static const _walletMessageTypes = <String>{'PAYMENT', 'WALLET'};

  void Function()? _walletRelatedMessageCallback;

  /// Called whenever a PAYMENT/WALLET push arrives — foreground
  /// ([FirebaseMessaging.onMessage]) or tapped ([_handleNotificationTap]) —
  /// so the caller can refetch wallet balance.
  void setWalletRelatedMessageCallback(void Function() callback) {
    _walletRelatedMessageCallback = callback;
  }

  static const _orderMessageTypes = <String>{
    'ORDER_STATUS',
    'ORDER_UPDATE',
    'DELIVERY',
    'RIDER_UPDATE',
  };

  void Function(String orderId, {required bool wallet})?
      _orderRelatedMessageCallback;

  /// Called whenever an order/refund push arrives (foreground) or is tapped
  /// (background/cold start) — a push-triggered sync, so the order screen
  /// converges on the new status even when the socket is down. [wallet] is
  /// true for a refund-request update (the wallet balance may have changed).
  void setOrderRelatedMessageCallback(
    void Function(String orderId, {required bool wallet}) callback,
  ) {
    _orderRelatedMessageCallback = callback;
  }

  void _notifyIfOrderRelated(Map<String, dynamic> data) {
    final type = (data['type'] ?? data['notificationType'] ?? '')
        .toString()
        .toUpperCase();
    final orderId = (data['orderId'] ?? data['order_id'] ?? '').toString();
    if (!_orderMessageTypes.contains(type) || orderId.isEmpty) return;
    final isRefund = (data['refundRequestId'] ?? '').toString().isNotEmpty;
    _orderRelatedMessageCallback?.call(orderId, wallet: isRefund);
  }

  void _notifyIfWalletRelated(Map<String, dynamic> data) {
    final type = (data['type'] ?? data['notificationType'] ?? '')
        .toString()
        .toUpperCase();
    if (_walletMessageTypes.contains(type)) {
      _walletRelatedMessageCallback?.call();
    }
  }
}
