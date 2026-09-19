import 'package:flutter/material.dart';

/// Root/jailbreak detection has no meaningful browser equivalent.
class RootDetection {
  RootDetection._();

  static Future<bool> blockIfCompromised(BuildContext context) async => false;
}
