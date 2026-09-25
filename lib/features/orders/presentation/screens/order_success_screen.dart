import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';

/// Transient "order placed" celebration — plays the success Lottie once,
/// then goes straight into the real Order Details screen (`/orders/:id`).
/// There is intentionally no summary/confirmation UI here any more: this
/// screen's only job is the animation before handing off.
class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({
    required this.orderId,
    super.key,
  });

  final String orderId;

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _fallbackTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          _goToOrderDetail();
        }
      });
    // Safety net in case the Lottie asset fails to load/decode — never
    // strand the user on this screen indefinitely.
    _fallbackTimer = Timer(const Duration(seconds: 3), _goToOrderDetail);
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _goToOrderDetail() {
    if (_navigated || !mounted) {
      return;
    }
    _navigated = true;
    _fallbackTimer?.cancel();
    context.go('/orders/${widget.orderId}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 260,
              height: 260,
              child: Lottie.asset(
                'assets/animations/order_placed_success.json',
                controller: _controller,
                repeat: false,
                onLoaded: (LottieComposition composition) {
                  _controller
                    ..duration = composition.duration
                    ..forward();
                },
                errorBuilder: (_, __, ___) {
                  // Asset failed to decode — fall back immediately instead
                  // of waiting out the full timer.
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _goToOrderDetail());
                  return const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primaryGreen,
                    size: 120,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Order placed successfully',
              style: AppTextStyles.h3.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
