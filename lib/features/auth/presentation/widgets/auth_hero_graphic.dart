import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';

class AuthHeroGraphic extends StatefulWidget {
  const AuthHeroGraphic({
    required this.title,
    required this.subtitle,
    super.key,
  });

  final String title;
  final String subtitle;

  @override
  State<AuthHeroGraphic> createState() => _AuthHeroGraphicState();
}

class _AuthHeroGraphicState extends State<AuthHeroGraphic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(
          width: 220.w,
          height: 180.h,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final wave = math.sin(_controller.value * math.pi * 2);
              return Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  _Bubble(
                    size: 140,
                    dx: wave * 16,
                    dy: -18,
                    color: AppColors.primaryGreenLight,
                  ),
                  _Bubble(
                    size: 88,
                    dx: -wave * 20,
                    dy: 38,
                    color: AppColors.accentYellowLight,
                  ),
                  Transform.translate(
                    offset: Offset(0, wave * 8),
                    child: Container(
                      width: 102.w,
                      height: 102.w,
                      decoration: BoxDecoration(
                        gradient: AppColors.heroGradient,
                        borderRadius: BorderRadius.circular(28.r),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x240C831F),
                            blurRadius: 24,
                            offset: Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Center(
                        child: PhosphorIcon(
                          PhosphorIcons.shoppingBagFill,
                          size: 40.sp,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Gap(18.h),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: AppTextStyles.h1.copyWith(fontSize: 30.sp, height: 1.15),
        ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.08, end: 0),
        Gap(10.h),
        Text(
          widget.subtitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textSecondary,
            height: 1.65,
          ),
        ).animate().fadeIn(delay: 80.ms, duration: 240.ms),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.size,
    required this.dx,
    required this.dy,
    required this.color,
  });

  final double size;
  final double dx;
  final double dy;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(dx.w, dy.h),
      child: Container(
        width: size.w,
        height: size.w,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
