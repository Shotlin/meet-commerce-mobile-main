import 'package:flutter/material.dart';
import 'package:bakaloo_flutter_app/shared/widgets/store_screen_shell.dart';

/// Cafe — renders via dynamic section engine.
/// storeIndex 3 maps to appStores[3] (cafe).
class CafeScreen extends StatelessWidget {
  const CafeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StoreScreenShell(storeIndex: 3);
  }
}
