import 'package:maplibre_gl/maplibre_gl.dart';

/// Keeps Android's MapLibre composition workaround out of browser builds.
Future<void> initializePlatformStartup() async {
  MapLibreMap.useHybridComposition = true;
}
