import 'package:flutter/material.dart';
import 'package:bakaloo_flutter_app/shared/widgets/store_screen_shell.dart';

/// 50% OFF Zone — renders via dynamic section engine.
/// storeIndex 1 maps to appStores[1] (off_zone).
class OffZoneScreen extends StatelessWidget {
  const OffZoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StoreScreenShell(storeIndex: 1);
  }
}
