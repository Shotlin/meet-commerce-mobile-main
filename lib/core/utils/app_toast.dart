import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';

enum ToastType { error, warning, success, info }

class AppToast {
  AppToast._();

  static OverlayEntry? _currentEntry;

  static ToastType _inferType(String message) {
    final lower = message.toLowerCase();

    if (lower.contains('refresh token') ||
        lower.contains('expired') ||
        lower.contains('jwt') ||
        lower.contains('unauthorized') ||
        lower.contains('not authenticated') ||
        lower.contains('session') ||
        lower.contains('sign in') ||
        lower.contains('log in')) {
      return ToastType.error;
    }

    if (lower.contains('maximum') ||
        lower.contains('max ') ||
        lower.contains('unavailable') ||
        lower.contains('not available') ||
        lower.contains('set your delivery') ||
        lower.contains('address required') ||
        lower.contains('delivery address')) {
      return ToastType.warning;
    }

    if (lower.contains('successfully') ||
        lower.contains('cancelled') ||
        lower.contains('deleted') ||
        lower.contains('added to cart') ||
        lower.contains('saved') ||
        lower.contains('updated') ||
        lower.contains('removed') ||
        lower.contains('complete')) {
      return ToastType.success;
    }

    if (lower.contains('coming soon')) {
      return ToastType.info;
    }

    return ToastType.error;
  }

  static void show(
    BuildContext context,
    String message, {
    ToastType? type,
    Duration duration = const Duration(milliseconds: 3500),
  }) {
    // rootOverlay: true — escapes StatefulShellRoute's per-tab nested
    // Overlay so the toast always paints above the bottom nav shell,
    // regardless of which tab/branch context triggered it.
    final overlay = Overlay.of(context, rootOverlay: true);

    // Remove any existing toast — never stack
    _currentEntry?.remove();
    _currentEntry = null;

    final resolvedType = type ?? _inferType(message);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastOverlay(
        message: message,
        type: resolvedType,
        entry: entry,
        duration: duration,
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

// ---------------------------------------------------------------------------
// Internal overlay widget — handles animation lifecycle
// ---------------------------------------------------------------------------

class _ToastOverlay extends StatefulWidget {
  const _ToastOverlay({
    required this.message,
    required this.type,
    required this.entry,
    required this.duration,
  });

  final String message;
  final ToastType type;
  final OverlayEntry entry;
  final Duration duration;

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ),);

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();

    // Auto-dismiss after duration
    Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (!mounted) return;
      widget.entry.remove();
      if (AppToast._currentEntry == widget.entry) {
        AppToast._currentEntry = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
              child: GestureDetector(
                onTap: _dismiss,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _ToastCard(
                      message: widget.message,
                      type: widget.type,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Visual card — stateless, pure presentation
// ---------------------------------------------------------------------------

class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.message,
    required this.type,
  });

  final String message;
  final ToastType type;

  @override
  Widget build(BuildContext context) {
    final accentColor = _accentColor(type);
    final icon = _icon(type);

    return Container(
      decoration: BoxDecoration(
        // Opaque, lightly tinted background so the message is always legible
        // against whatever content sits behind the overlay.
        color: Color.alphaBlend(
          accentColor.withValues(alpha: 0.14),
          Colors.white,
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border(
          left: BorderSide(color: accentColor, width: 4),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1.h),
            child: PhosphorIcon(icon, size: 20.sp, color: accentColor),
          ),
          Gap(10.w),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _accentColor(ToastType type) {
    switch (type) {
      case ToastType.error:
        return AppColors.errorRed;
      case ToastType.warning:
        return AppColors.warningOrange;
      case ToastType.success:
        return AppColors.successGreen;
      case ToastType.info:
        return AppColors.infoBlue;
    }
  }

  static PhosphorIconData _icon(ToastType type) {
    switch (type) {
      case ToastType.error:
        return PhosphorIcons.xCircle;
      case ToastType.warning:
        return PhosphorIcons.warning;
      case ToastType.success:
        return PhosphorIcons.checkCircle;
      case ToastType.info:
        return PhosphorIcons.info;
    }
  }
}
