import 'package:flutter/material.dart';

class AppShadows {
  AppShadows._();

  static const cardShadow = BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  static const floatingShadow = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 16,
    offset: Offset(0, -4),
  );

  static const inputShadow = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 6,
    offset: Offset(0, 2),
  );

  static const actionBtnShadow = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  static const bottomBarShadow = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 12,
    offset: Offset(0, -3),
  );

  static const cartBtnGlow = BoxShadow(
    color: Color(0x4DE91E63),
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  static const retroPriceShadow = BoxShadow(
    color: Color(0xFF000000),
    blurRadius: 0,
    offset: Offset(2, 2),
  );
}
