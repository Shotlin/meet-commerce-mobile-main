import 'package:flutter/material.dart';

class ActiveChipClipper extends CustomClipper<Path> {
  const ActiveChipClipper();

  @override
  Path getClip(Size size) {
    const r = 20.0;

    return Path()
      ..moveTo(r, 0)
      ..lineTo(size.width - r, 0)
      ..quadraticBezierTo(size.width, 0, size.width, r)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
