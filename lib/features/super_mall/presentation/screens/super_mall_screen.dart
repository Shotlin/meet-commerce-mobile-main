import 'package:flutter/material.dart';
import 'package:bakaloo_flutter_app/shared/widgets/store_screen_shell.dart';

/// Super Mall — renders via dynamic section engine.
/// storeIndex 2 maps to appStores[2] (super_mall).
class SuperMallScreen extends StatelessWidget {
  const SuperMallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StoreScreenShell(storeIndex: 2);
  }
}
