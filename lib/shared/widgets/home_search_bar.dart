import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';

const List<String> _searchHints = <String>[
  'chicken',
  'eggs',
  'mutton',
  'fish',
  'grocery',
  'vegetables',
  'Milk',
  'fruits',
  'snacks',
];
const String _searchIconAsset = 'assets/icon/bakaloo-search-icon.png';

class HomeSearchBar extends StatefulWidget {
  const HomeSearchBar({
    required this.onSearchTap,
    this.animateHints = true,
    this.searchTheme,
    this.outerPadding,
    super.key,
  });

  final VoidCallback onSearchTap;
  final bool animateHints;
  final SearchZoneTheme? searchTheme;
  final EdgeInsetsGeometry? outerPadding;

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  int _hintIndex = 0;
  Timer? _hintTimer;

  static const Color _borderColor = Color(0xFFF0DEDE);
  static const Color _hintColor = Color(0xFF6B6770);

  // Deliberately ignores widget.searchTheme?.searchHints — that field is
  // driven by the per-tab remote theme config (All/Fresh/Dairy/Price Drop
  // each fetch their own theme row), which led to mismatched hints like
  // "iPhone, Samsung Galaxy" showing up under grocery tabs. The rotating
  // preview text is meant to be one fixed, global list regardless of tab.
  List<String> get _resolvedSearchHints => _searchHints;

  @override
  void initState() {
    super.initState();
    _syncHintRotation();
  }

  @override
  void didUpdateWidget(covariant HomeSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animateHints != widget.animateHints) {
      _syncHintRotation();
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  void _syncHintRotation() {
    _hintTimer?.cancel();
    final searchHints = _resolvedSearchHints;
    if (_hintIndex >= searchHints.length) {
      _hintIndex = 0;
    }
    if (!widget.animateHints) {
      _hintTimer = null;
      return;
    }
    if (searchHints.length <= 1) {
      return;
    }

    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) {
        return;
      }
      final hints = _resolvedSearchHints;
      if (hints.isEmpty) {
        return;
      }
      setState(() {
        _hintIndex = (_hintIndex + 1) % hints.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchHints = _resolvedSearchHints;
    final BorderRadius borderRadius = BorderRadius.circular(12.r);
    final hintLabel = Align(
      alignment: Alignment.centerLeft,
      key: ValueKey<int>(_hintIndex),
      child: Text(
        "Search '${searchHints[_hintIndex]}'",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 15.sp,
          color: _hintColor,
          fontWeight: FontWeight.w400,
          height: 1,
        ),
      ),
    );

    // Full-width search bar — Everyday Essentials promo box removed.
    return Padding(
      padding: widget.outerPadding ?? EdgeInsets.fromLTRB(12.w, 7.h, 12.w, 0),
      child: SizedBox(
        height: 50.h,
        child: Semantics(
          button: true,
          label: 'Search Bakaloo products',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onSearchTap,
              borderRadius: borderRadius,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: borderRadius,
                  border: Border.all(color: _borderColor),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFF2A1A47).withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                child: Row(
                  children: <Widget>[
                    Image.asset(
                      _searchIconAsset,
                      width: 22.w,
                      height: 22.w,
                      cacheWidth: 176,
                      cacheHeight: 176,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                    Gap(10.w),
                    Expanded(
                      child: widget.animateHints
                          ? AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                              layoutBuilder: (
                                Widget? currentChild,
                                List<Widget> previousChildren,
                              ) {
                                return SizedBox.expand(
                                  child: Stack(
                                    alignment: Alignment.centerLeft,
                                    children: <Widget>[
                                      ...previousChildren,
                                      if (currentChild != null) currentChild,
                                    ],
                                  ),
                                );
                              },
                              child: hintLabel,
                            )
                          : hintLabel,
                    ),
                    Gap(10.w),
                    Container(
                      width: 1,
                      height: 22.h,
                      color: _borderColor,
                    ),
                    Gap(10.w),
                    // Voice search — mirrors the mic already on the full
                    // search screen (speech_to_text); replaces the old
                    // QR-style scan icon, which nothing in the app used.
                    PhosphorIcon(
                      PhosphorIcons.microphoneBold,
                      size: 22.sp,
                      color: AppColors.brandRed,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
