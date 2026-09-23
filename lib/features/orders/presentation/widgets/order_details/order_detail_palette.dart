import 'package:flutter/material.dart';

/// Color/type tokens for the Order Details screen only.
///
/// Deliberately not merged into the shared `AppColors` (which already has
/// its own, slightly different, app-wide `brandRed` = 0xFFD02428): this
/// screen was speced against an exact reference palette (#C32D2E / #E51F2A)
/// and must match it pixel-for-pixel, without nudging every other red
/// accent in the app that already relies on `AppColors.brandRed`.
class OrderDetailPalette {
  OrderDetailPalette._();

  static const primaryRed = Color(0xFFC32D2E);
  static const ctaRed = Color(0xFFE51F2A);
  static const ctaRedPressed = Color(0xFFC61A24);
  static const white = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF111318);
  static const textSecondary = Color(0xFF6F7785);
  static const border = Color(0xFFEAECF0);
  static const successGreen = Color(0xFF22B45A);

  static const screenBg = Color(0xFFF7F7F8);
  static const surfaceMuted = Color(0xFFF5F5F7);
  static const primaryRedSurface = Color(0x14C32D2E);
  static const successGreenSurface = Color(0x1422B45A);
  static const errorSurface = Color(0x14D32F2F);
  static const disabled = Color(0xFFAAAAAA);

  static const cardShadow = BoxShadow(
    color: Color(0x0A111318),
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  static const stickyBarShadow = BoxShadow(
    color: Color(0x14111318),
    blurRadius: 16,
    offset: Offset(0, -4),
  );
}
