import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _androidChannelId = 'bakaloo_notifications';
  static const _androidChannelName = 'Bakaloo Notifications';
  static const _androidChannelDescription = 'Order, payment and app updates';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize({
    void Function(Map<String, dynamic> payload)? onTap,
  }) async {
    if (_initialized) {
      return;
    }

    // A full-color launcher icon here renders wrong on Android's status bar
    // — notification icons are forced through an alpha-only silhouette mask
    // (Android 5.0+), so ic_launcher either shows as a blank white blob or
    // falls back to a generic placeholder. ic_stat_notification is a
    // proper white-on-transparent silhouette made for this purpose.
    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_stat_notification');
    const iosSettings = DarwinInitializationSettings();

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty || onTap == null) {
          return;
        }

        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            onTap(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {
          // Ignore malformed payloads.
        }
      },
    );

    const channel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: _androidChannelDescription,
      importance: Importance.max,
    );
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<void> show(RemoteMessage message) async {
    final title = _stringValue(message.data['title']) ??
        message.notification?.title ??
        'Bakaloo';
    final body =
        _stringValue(message.data['body']) ?? message.notification?.body ?? '';

    if (title.isEmpty && body.isEmpty) {
      return;
    }

    final idSeed = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final notificationId = idSeed.remainder(2147483647);

    // Check for image URL in data payload or notification
    final imageUrl = _stringValue(message.data['imageUrl']) ??
        _stringValue(message.data['image_url']) ??
        message.notification?.android?.imageUrl;

    AndroidNotificationDetails androidDetails;
    if (imageUrl != null && imageUrl.startsWith('https://')) {
      // Big picture style for image notifications
      try {
        final styleInfo = BigPictureStyleInformation(
          FilePathAndroidBitmap(imageUrl),
          hideExpandedLargeIcon: true,
          contentTitle: title,
          summaryText: body,
        );
        androidDetails = AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          styleInformation: styleInfo,
        );
      } catch (_) {
        // Fall back to normal if image fails
        androidDetails = _defaultAndroidDetails();
      }
    } else {
      androidDetails = _defaultAndroidDetails();
    }

    await _plugin.show(
      notificationId,
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  AndroidNotificationDetails _defaultAndroidDetails() {
    return const AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
  }

  String? _stringValue(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }
}
