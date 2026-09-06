import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class ExpandableSection extends StatefulWidget {
  const ExpandableSection({
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
    this.topBorder = true,
    this.titleFontSize,
    this.titleWeight,
    this.titleHeight,
    this.onToggle,
    super.key,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;
  final bool topBorder;
  final double? titleFontSize;
  final FontWeight? titleWeight;
  final double? titleHeight;
  final VoidCallback? onToggle;

  @override
  State<ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<ExpandableSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  void _toggle() {
    final willExpand = !_isExpanded;
    setState(() {
      _isExpanded = willExpand;
    });
    if (willExpand && widget.onToggle != null) {
      widget.onToggle!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.topBorder)
          Container(
            height: 1.h,
            color: const Color(0xFFEEEEEE),
          ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: Container(
            height: 56.h,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: widget.titleFontSize ?? 17.sp,
                      fontWeight: widget.titleWeight ?? FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                      height: widget.titleHeight ?? 1.2,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: PhosphorIcon(
                    PhosphorIcons.caretDown,
                    size: 22.sp,
                    color: const Color(0xFF333333),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 280),
          crossFadeState: _isExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: widget.child,
          secondChild: const SizedBox.shrink(),
          firstCurve: Curves.easeInOut,
          secondCurve: Curves.easeInOut,
        ),
      ],
    );
  }
}
