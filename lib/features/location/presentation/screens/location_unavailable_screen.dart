import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/widgets/bakaloo_state_screen.dart';

/// Shown when Bakaloo does not yet serve the customer's area (no shops match
/// the pincode/radius). Uses the shared [BakalooStateScreen] "box" style so it
/// stays visually identical to the offline screen.
class LocationUnavailableScreen extends StatelessWidget {
  const LocationUnavailableScreen({
    this.onChangeLocation,
    this.onNotify,
    super.key,
  });

  /// Optional overrides — primarily for previewing/testing. When omitted the
  /// screen wires sensible default navigation.
  final VoidCallback? onChangeLocation;
  final VoidCallback? onNotify;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: BakalooStateScreen(
        illustrationAsset:
            'assets/images/bakaloo-location-unavailable-illustration.png',
        icon: PhosphorIcons.gpsSlashBold,
        title: "We're not in your area yet",
        subtitle:
            "We're expanding fast. Try a different location\n"
            'or enable location access to check availability.',
        primaryLabel: 'Change location',
        onPrimary: onChangeLocation ??
            () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(RouteNames.addresses);
              }
            },
        secondaryLabel: 'Notify me when available',
        onSecondary: onNotify ??
            () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Thanks! We'll notify you when Bakaloo reaches your area.",
                    ),
                  ),
                );
            },
      ),
    );
  }
}
