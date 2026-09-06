import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Resolves a banner/tile "link" target and navigates: a full external URL
/// (has a scheme + host) opens in the system browser, anything else is
/// treated as an in-app route and pushed via GoRouter. Shared by every
/// theme-builder widget that reads a plain resolved link string from
/// `config.link_url` (Animated Banner, Custom Banner, Promo Carousel).
Future<void> handleLinkTap(BuildContext context, String target) async {
  final uri = Uri.tryParse(target);
  if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }

  if (!context.mounted) {
    return;
  }

  context.push(target.startsWith('/') ? target : '/$target');
}
