import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScreenshotPrevention {
  ScreenshotPrevention._();

  static const MethodChannel _channel = MethodChannel('bakaloo/security');

  static Future<void> enable() async {
    if (kIsWeb) {
      return;
    }
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<void>('enableSecure');
      } catch (_) {
        // Security hardening should fail silently without blocking UX.
      }
    }
  }

  static Future<void> disable() async {
    if (kIsWeb) {
      return;
    }
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<void>('disableSecure');
      } catch (_) {
        // Security hardening should fail silently without blocking UX.
      }
    }
  }
}
