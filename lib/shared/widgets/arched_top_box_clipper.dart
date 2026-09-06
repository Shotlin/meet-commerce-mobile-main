import 'package:flutter/rendering.dart';

/// A [CustomClipper] that creates a rounded rectangle where the **top edge**
/// is a convex (upward-curving) arch, giving the container a soft, "puffy" look.
///
/// The bottom and side edges use standard circular arcs with [radius].
/// The top edge uses a [quadraticBezierTo] whose control point is lifted
/// [archHeight] pixels above the bounding box.
class ArchedTopBoxClipper extends CustomClipper<Path> {
  const ArchedTopBoxClipper({
    this.radius = 24.0,
    this.archHeight = 14.0,
  });

  /// Corner radius applied to all four corners.
  final double radius;

  /// How far the top edge arch rises above the bounding box (in logical pixels).
  /// A value of `0` results in a flat top edge.
  final double archHeight;

  @override
  Path getClip(Size size) {
    final double w = size.width;
    final double h = size.height;
    final double r = radius.clamp(0, h / 2);

    return Path()
      // ── Start at bottom-left (just above the corner) ──
      ..moveTo(0, h - r)
      // ── Bottom-left corner arc ──
      ..arcToPoint(
        Offset(r, h),
        radius: Radius.circular(r),
        clockwise: false,
      )
      // ── Bottom edge → bottom-right ──
      ..lineTo(w - r, h)
      // ── Bottom-right corner arc ──
      ..arcToPoint(
        Offset(w, h - r),
        radius: Radius.circular(r),
        clockwise: false,
      )
      // ── Right edge → top-right corner ──
      ..lineTo(w, archHeight + r)
      // ── Top-right corner arc ──
      ..arcToPoint(
        Offset(w - r, archHeight),
        radius: Radius.circular(r),
        clockwise: false,
      )
      // ── Top edge: convex arch via quadratic Bézier ──
      ..quadraticBezierTo(
        w / 2, // control point X  → horizontal center
        -archHeight, // control point Y  → pulls curve up to Y=0 at peak
        r, // end X            → left side (after corner)
        archHeight, // end Y            → base of the top edge
      )
      // ── Top-left corner arc ──
      ..arcToPoint(
        Offset(0, archHeight + r),
        radius: Radius.circular(r),
        clockwise: false,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant ArchedTopBoxClipper oldClipper) =>
      radius != oldClipper.radius || archHeight != oldClipper.archHeight;
}
