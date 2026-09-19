import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Which side of the [B2BSegmentToggle] is active.
enum BusinessMode { b2c, b2b }

/// Bakaloo-style B2C / B2B segmented toggle.
///
/// A hand-built pill (no [Switch], [ToggleButtons] or
/// [CupertinoSegmentedControl]) sized 170x58 at its natural scale and
/// stretched to fill whatever width it's given while keeping that aspect
/// ratio — wrap it in a [SizedBox]/[Expanded] to control width, or drop it
/// in as-is for the default size.
class B2BSegmentToggle extends StatelessWidget {
  const B2BSegmentToggle({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final BusinessMode value;
  final ValueChanged<BusinessMode> onChanged;

  static const double _baseWidth = 170;
  static const double _baseHeight = 58;
  static const Color _red = Color(0xFFC32D2E);
  static const Color _border = Color(0xFFE6E6E6);
  static const Color _activeText = Color(0xFFFFFFFF);
  static const Color _inactiveText = Color(0xFF111318);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width =
            constraints.hasBoundedWidth && constraints.maxWidth < _baseWidth
                ? constraints.maxWidth
                : _baseWidth;
        final double height = width * (_baseHeight / _baseWidth);
        return SizedBox(
          width: width,
          height: height,
          child: _Toggle(
            value: value,
            onChanged: onChanged,
            width: width,
            height: height,
            scale: width / _baseWidth,
          ),
        );
      },
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.value,
    required this.onChanged,
    required this.width,
    required this.height,
    required this.scale,
  });

  final BusinessMode value;
  final ValueChanged<BusinessMode> onChanged;
  final double width;
  final double height;
  final double scale;

  static const Duration _duration = Duration(milliseconds: 180);
  static const Curve _curve = Curves.easeOutCubic;

  void _select(BusinessMode mode) {
    if (mode == value) return;
    HapticFeedback.selectionClick();
    onChanged(mode);
  }

  @override
  Widget build(BuildContext context) {
    final double outerRadius = height / 2;
    final double innerMargin = height * (2 / 58);
    final double innerRadius = (height - innerMargin * 2) / 2;
    final bool isB2b = value == BusinessMode.b2b;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final bool tappedRight = details.localPosition.dx > width / 2;
        _select(tappedRight ? BusinessMode.b2b : BusinessMode.b2c);
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(outerRadius),
          border: Border.all(color: B2BSegmentToggle._border, width: 1),
        ),
        child: Stack(
          children: <Widget>[
            // Selected red capsule, animated between the two halves.
            AnimatedPositioned(
              duration: _duration,
              curve: _curve,
              top: innerMargin,
              bottom: innerMargin,
              left: isB2b ? width / 2 : innerMargin,
              right: isB2b ? innerMargin : width / 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: B2BSegmentToggle._red,
                  borderRadius: BorderRadius.circular(innerRadius),
                ),
              ),
            ),
            // Labels — text color animates in lockstep with the capsule.
            Row(
              children: <Widget>[
                Expanded(
                  child: _Label(
                    text: 'B2C',
                    selected: !isB2b,
                    duration: _duration,
                    curve: _curve,
                    scale: scale,
                  ),
                ),
                Expanded(
                  child: _Label(
                    text: 'B2B',
                    selected: isB2b,
                    duration: _duration,
                    curve: _curve,
                    scale: scale,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({
    required this.text,
    required this.selected,
    required this.duration,
    required this.curve,
    required this.scale,
  });

  final String text;
  final bool selected;
  final Duration duration;
  final Curve curve;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedDefaultTextStyle(
        duration: duration,
        curve: curve,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18 * scale,
          fontWeight: FontWeight.w700,
          color: selected
              ? B2BSegmentToggle._activeText
              : B2BSegmentToggle._inactiveText,
          height: 1,
        ),
        child: Text(text),
      ),
    );
  }
}
