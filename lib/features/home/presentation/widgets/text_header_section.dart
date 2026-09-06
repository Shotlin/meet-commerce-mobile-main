import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class TextHeaderSection extends StatelessWidget {
  const TextHeaderSection({
    required this.text,
    super.key,
    this.fontSize = 18,
    this.color = '#000000',
    this.alignment = 'left',
  });

  final String text;
  final double fontSize;
  final String color;
  final String alignment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
      child: Align(
        alignment: _resolveAlignment(alignment),
        child: Text(
          text,
          textAlign: _resolveTextAlign(alignment),
          style: TextStyle(
            fontSize: fontSize.sp,
            fontWeight: FontWeight.w700,
            color: _parseHexColor(color),
            height: 1.15,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

Alignment _resolveAlignment(String value) {
  switch (value.trim().toLowerCase()) {
    case 'center':
      return Alignment.center;
    case 'right':
      return Alignment.centerRight;
    default:
      return Alignment.centerLeft;
  }
}

TextAlign _resolveTextAlign(String value) {
  switch (value.trim().toLowerCase()) {
    case 'center':
      return TextAlign.center;
    case 'right':
      return TextAlign.right;
    default:
      return TextAlign.left;
  }
}

Color _parseHexColor(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return const Color(0xFF000000);
  }

  final cleaned = normalized.replaceFirst('#', '');
  final hex = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) {
    return const Color(0xFF000000);
  }
  return Color(parsed);
}
