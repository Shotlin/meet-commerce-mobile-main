import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/branding/branding_provider.dart';
import 'package:bakaloo_flutter_app/features/splash/splash_provider.dart';
import 'package:bakaloo_flutter_app/shared/widgets/app_image.dart';

const String _defaultSplashAsset = 'assets/images/bakaloo-splash-screen.png';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Best-effort refresh so a dashboard-changed splash/logo is cached
    // before the *next* cold start; never blocks this frame's render.
    unawaited(ref.read(brandingProvider.notifier).refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(splashControllerProvider.notifier).handleStartup(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final splashImageUrl = ref.watch(
      brandingProvider.select((config) => config.splashImageUrl),
    );

    return Scaffold(
      body: SizedBox.expand(
        child: splashImageUrl == null
            ? Image.asset(_defaultSplashAsset, fit: BoxFit.cover)
            : AppImage(
                imageUrl: splashImageUrl,
                memCacheWidth: 1080,
                memCacheHeight: 1920,
                fit: BoxFit.cover,
                placeholder: Image.asset(_defaultSplashAsset, fit: BoxFit.cover),
                errorWidget: Image.asset(_defaultSplashAsset, fit: BoxFit.cover),
              ),
      ),
    );
  }
}
