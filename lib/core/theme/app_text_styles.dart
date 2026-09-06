import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';

/// Font strategy for Bakaloo — Grocery Super App
///
/// ┌─────────────────────────────────────────────────────────────────┐
/// │  PlusJakartaSans  →  headings, prices, buttons, section titles  │
/// │  DMSans           →  body, product names, labels, descriptions  │
/// └─────────────────────────────────────────────────────────────────┘
///
/// Why PlusJakartaSans for headings:
///   Geometric sans-serif with subtle humanist warmth. Its Bold/ExtraBold
///   weights feel energetic and fresh — exactly the emotion you want when
///   a customer sees "Fresh Vegetables" or "₹11". Used widely in premium
///   quick-commerce apps because it reads fast at any size.
///
/// Why DM Sans for body:
///   Designed specifically for small-screen readability. Slightly rounder
///   than Inter, warmer than Roboto. At 12–14sp (where most grocery text
///   lives) it is sharper and more legible than Poppins. Conveys trust
///   and ease — the feeling you want for product names, cart items, and
///   checkout details.
class AppTextStyles {
  AppTextStyles._();

  // ── Display / Hero ────────────────────────────────────────────────────────
  static final display = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 28.sp,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.18,
    letterSpacing: -0.3,
  );

  // ── Headings ──────────────────────────────────────────────────────────────
  static final h1 = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 22.sp,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
    letterSpacing: -0.2,
  );

  static final h2 = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 18.sp,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: -0.1,
  );

  static final h3 = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 16.sp,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  // ── Body ──────────────────────────────────────────────────────────────────
  static final bodyLarge = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 15.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static final bodyMedium = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static final bodySmall = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 12.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
    height: 1.5,
  );

  // ── Prices (PlusJakartaSans — numbers pop with geometric boldness) ────────
  static final priceMain = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 22.sp,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static final priceMRP = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 15.sp,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
    decoration: TextDecoration.lineThrough,
  );

  // ── Buttons (PlusJakartaSans — energetic, action-oriented) ───────────────
  static final buttonLarge = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 16.sp,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  static final buttonMedium = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 14.sp,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static final buttonSmall = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 13.sp,
    fontWeight: FontWeight.w600,
  );

  // ── Labels / chips (DMSans — readable at small sizes) ────────────────────
  static final labelLarge = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 13.sp,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static final labelSmall = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 11.sp,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static final chip = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 12.sp,
    fontWeight: FontWeight.w600,
  );

  static final categoryName = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 12.sp,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );
}
