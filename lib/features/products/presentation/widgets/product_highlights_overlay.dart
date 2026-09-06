import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class ProductHighlightsOverlay extends StatefulWidget {
  const ProductHighlightsOverlay({
    required this.highlights,
    required this.isVisible,
    required this.onClose,
    super.key,
  });

  final Map<String, dynamic> highlights;
  final bool isVisible;
  final VoidCallback onClose;

  @override
  State<ProductHighlightsOverlay> createState() =>
      _ProductHighlightsOverlayState();
}

class _ProductHighlightsOverlayState extends State<ProductHighlightsOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
      value: widget.isVisible ? 1 : 0,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeIn,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant ProductHighlightsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible == oldWidget.isVisible) {
      return;
    }
    if (widget.isVisible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.highlights.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 231.h,
      child: IgnorePointer(
        ignoring: !widget.isVisible,
        child: AnimatedOpacity(
          opacity: widget.isVisible ? 1 : 0,
          duration: Duration(milliseconds: widget.isVisible ? 300 : 200),
          curve: widget.isVisible ? Curves.easeOutCubic : Curves.easeIn,
          child: SlideTransition(
            position: _slideAnimation,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    Color(0xA6000000),
                  ],
                ),
              ),
              child: Stack(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 76.h),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Highlights',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          ...widget.highlights.entries.expand((entry) {
                            return <Widget>[
                              Text(
                                entry.key,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0x8CFFFFFF),
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                '${entry.value}',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 12.h),
                            ];
                          }),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16.w,
                    bottom: 20.h,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onClose,
                      child: Container(
                        width: 38.w,
                        height: 38.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              const Color(0xFF333333).withValues(alpha: 0.85),
                        ),
                        child: Center(
                          child: PhosphorIcon(
                            PhosphorIcons.x,
                            size: 18.sp,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
