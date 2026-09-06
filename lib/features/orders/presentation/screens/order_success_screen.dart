import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/datetime_extensions.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_timeline_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/presentation/providers/order_detail_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

class OrderSuccessScreen extends ConsumerStatefulWidget {
  const OrderSuccessScreen({
    required this.orderId,
    super.key,
  });

  final String orderId;

  @override
  ConsumerState<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends ConsumerState<OrderSuccessScreen> {
  Timer? _autoRedirectTimer;
  int _secondsRemaining = 5;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _autoRedirectTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        _goToOrderDetail();
        return;
      }
      setState(() {
        _secondsRemaining -= 1;
      });
    });
  }

  @override
  void dispose() {
    _autoRedirectTimer?.cancel();
    super.dispose();
  }

  void _goToOrderDetail() {
    if (_navigated || !mounted) {
      return;
    }
    _navigated = true;
    context.go('/orders/${widget.orderId}');
  }

  void _goHome() {
    if (_navigated || !mounted) {
      return;
    }
    _navigated = true;
    context.go(RouteNames.home);
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      bottomNavigationBar: _SuccessBottomBar(
        onTrackOrder: _goToOrderDetail,
        onContinueShopping: _goHome,
      ),
      body: SafeArea(
        child: orderAsync.when(
          loading: () => _SuccessScaffold(
            secondsRemaining: _secondsRemaining,
            child: const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryGreen,
              ),
            ),
          ),
          error: (_, __) => _SuccessScaffold(
            secondsRemaining: _secondsRemaining,
            child: Column(
              children: <Widget>[
                _SuccessHero(
                  secondsRemaining: _secondsRemaining,
                  heading: 'Order confirmed',
                  subtitle:
                      'Your payment went through and we are preparing the order details.',
                  statusLabel: 'Confirmed',
                ),
                Gap(18.h),
                _DetailCard(
                  title: 'Order reference',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Order #${widget.orderId}',
                        style: AppTextStyles.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Gap(6.h),
                      Text(
                        'Opening live tracking automatically in a moment.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          data: (order) => _SuccessScaffold(
            secondsRemaining: _secondsRemaining,
            child: Column(
              children: <Widget>[
                _SuccessHero(
                  secondsRemaining: _secondsRemaining,
                  heading: 'Order placed successfully',
                  subtitle: _heroSubtitle(order),
                  statusLabel: order.status.label,
                ),
                Gap(18.h),
                _OrderMetrics(order: order),
                Gap(16.h),
                _DetailCard(
                  title: 'What happens next',
                  child: Column(
                    children: <Widget>[
                      _DetailRow(
                        icon: Icons.receipt_long_rounded,
                        label: 'Order',
                        value: order.orderNumber,
                      ),
                      ..._paymentRows(order),
                      _DetailRow(
                        icon: Icons.discount_outlined,
                        label: 'Savings',
                        value: order.discount > 0
                            ? order.discount.toInrCurrency
                            : 'No coupon applied',
                        valueColor: order.discount > 0
                            ? AppColors.successGreen
                            : AppColors.textSecondary,
                      ),
                      if (order.razorpayPaymentId != null)
                        _DetailRow(
                          icon: Icons.lock_outline_rounded,
                          label: 'Reference',
                          value: order.razorpayPaymentId!,
                        ),
                    ],
                  ),
                ),
                Gap(16.h),
                _DeliverySummaryCard(order: order),
                Gap(16.h),
                _ItemsPreviewCard(order: order),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _heroSubtitle(OrderEntity order) {
    final eta = order.estimatedDelivery?.toIndianDateTime;
    if (eta != null && eta.isNotEmpty) {
      return 'Your store has the order. Estimated delivery is $eta.';
    }
    return 'Your store has the order. We will keep the live tracking updated for you.';
  }
}

class _SuccessScaffold extends StatelessWidget {
  const _SuccessScaffold({
    required this.secondsRemaining,
    required this.child,
  });

  final int secondsRemaining;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 116.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusFull,
                  ),
                  boxShadow: const <BoxShadow>[AppShadows.cardShadow],
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.schedule_rounded,
                      size: 16.sp,
                      color: AppColors.primaryGreen,
                    ),
                    Gap(6.w),
                    Text(
                      'Opening tracking in ${secondsRemaining.clamp(1, 5)}s',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap(16.h),
          child,
        ],
      ),
    );
  }
}

class _SuccessHero extends StatelessWidget {
  const _SuccessHero({
    required this.secondsRemaining,
    required this.heading,
    required this.subtitle,
    required this.statusLabel,
  });

  final int secondsRemaining;
  final String heading;
  final String subtitle;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -26.h,
            right: -14.w,
            child: Container(
              width: 112.w,
              height: 112.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            left: -20.w,
            bottom: -24.h,
            child: Container(
              width: 84.w,
              height: 84.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusFull,
                              ),
                            ),
                            child: Text(
                              statusLabel,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          Gap(14.h),
                          Text(
                            heading,
                            style: AppTextStyles.h1.copyWith(
                              color: Colors.white,
                              fontSize: 28.sp,
                            ),
                          ),
                          Gap(8.h),
                          Text(
                            subtitle,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.88),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Gap(12.w),
                    SizedBox(
                      width: 104.w,
                      height: 104.w,
                      child: Lottie.asset(
                        'assets/animations/success_checkmark.json',
                        repeat: false,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(24.r),
                          ),
                          child: Center(
                            child: PhosphorIcon(
                              PhosphorIcons.checkCircleFill,
                              color: Colors.white,
                              size: 56.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Gap(18.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.navigation_rounded,
                        color: Colors.white,
                        size: 18.sp,
                      ),
                      Gap(8.w),
                      Expanded(
                        child: Text(
                          'Live tracking opens automatically in ${secondsRemaining.clamp(1, 5)} seconds.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderMetrics extends StatelessWidget {
  const _OrderMetrics({required this.order});

  final OrderEntity order;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _MetricCard(
            label: 'Total paid',
            value: order.total.toInrCurrency,
            icon: Icons.account_balance_wallet_outlined,
          ),
        ),
        Gap(12.w),
        Expanded(
          child: _MetricCard(
            label: 'Items',
            value: '${order.itemCount}',
            icon: Icons.shopping_bag_outlined,
          ),
        ),
        Gap(12.w),
        Expanded(
          child: _MetricCard(
            label: 'ETA',
            value: order.estimatedDelivery?.toIndianDateTime ?? 'Soon',
            icon: Icons.timer_outlined,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: AppColors.primaryGreenLight,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryGreen,
              size: 18.sp,
            ),
          ),
          Gap(10.h),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Gap(2.h),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        boxShadow: const <BoxShadow>[AppShadows.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppTextStyles.h3),
          Gap(14.h),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryGreen,
              size: 18.sp,
            ),
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Gap(2.h),
                Text(
                  value,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliverySummaryCard extends StatelessWidget {
  const _DeliverySummaryCard({required this.order});

  final OrderEntity order;

  @override
  Widget build(BuildContext context) {
    final address = order.deliveryAddress;
    final label = _readString(address, <String>['label'], fallback: 'Address');
    final name = _readString(address, <String>['name']);
    final phone = _readString(address, <String>['phone']);
    final line1 =
        _readString(address, <String>['addressLine1', 'address_line1']);
    final line2 =
        _readString(address, <String>['addressLine2', 'address_line2']);
    final city = _readString(address, <String>['city']);
    final state = _readString(address, <String>['state']);
    final pincode = _readString(address, <String>['pincode']);
    final summary = <String>[
      line1,
      if (line2.isNotEmpty) line2,
      <String>[city, state, pincode]
          .where((item) => item.isNotEmpty)
          .join(', '),
    ].where((item) => item.isNotEmpty).join(', ');

    return _DetailCard(
      title: 'Delivery details',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: AppColors.primaryGreenLight,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: AppColors.primaryGreen,
              size: 22.sp,
            ),
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$label${name.isNotEmpty ? ' • $name' : ''}',
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (phone.isNotEmpty) ...<Widget>[
                  Gap(4.h),
                  Text(
                    phone,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                Gap(6.h),
                Text(
                  summary,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsPreviewCard extends StatelessWidget {
  const _ItemsPreviewCard({required this.order});

  final OrderEntity order;

  @override
  Widget build(BuildContext context) {
    final visibleItems = order.items.take(3).toList(growable: false);
    final extraCount = order.items.length - visibleItems.length;

    return _DetailCard(
      title: 'Packed in this order',
      child: Column(
        children: <Widget>[
          for (final item in visibleItems)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: AppColors.bgInput,
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Center(
                      child: Text(
                        '${item.quantity}x',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Gap(12.w),
                  Expanded(
                    child: Text(
                      item.name,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Gap(8.w),
                  Text(
                    item.total.toInrCurrency,
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          if (extraCount > 0)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: AppColors.primaryGreenLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              ),
              child: Text(
                '+$extraCount more item${extraCount == 1 ? '' : 's'} in this order',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primaryGreenDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SuccessBottomBar extends StatelessWidget {
  const _SuccessBottomBar({
    required this.onTrackOrder,
    required this.onContinueShopping,
  });

  final VoidCallback onTrackOrder;
  final VoidCallback onContinueShopping;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: <BoxShadow>[AppShadows.floatingShadow],
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: onContinueShopping,
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, 52.h),
                  side: const BorderSide(color: AppColors.borderLight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
                child: Text(
                  'Shop more',
                  style: AppTextStyles.buttonMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            Gap(12.w),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: onTrackOrder,
                icon: Icon(
                  Icons.navigation_rounded,
                  size: 18.sp,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  minimumSize: Size(double.infinity, 52.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
                label: Text(
                  'Track order',
                  style: AppTextStyles.buttonMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "What happens next" card's payment row(s) — split into a wallet
/// line and a remainder line whenever the wallet-balance toggle covered
/// part of the total, instead of a single "COD • Pending" row that erases
/// the fact that part of this order was already paid from the wallet.
List<Widget> _paymentRows(OrderEntity order) {
  final walletUsed = order.walletAmountUsed;
  if (walletUsed <= 0) {
    return <Widget>[
      _DetailRow(
        icon: Icons.payments_outlined,
        label: 'Payment',
        value:
            '${_prettyText(order.paymentMethod)} • ${_prettyText(order.paymentStatus)}',
      ),
    ];
  }

  final remainder = order.total - walletUsed;
  final walletRow = _DetailRow(
    icon: Icons.account_balance_wallet_rounded,
    label: 'Wallet',
    value: '${walletUsed.toInrCurrency} deducted',
    valueColor: AppColors.orderViolet,
  );

  // Wallet covered the whole order — nothing left to collect via COD/Online,
  // so there's no second row to show.
  if (remainder <= 0) {
    return <Widget>[walletRow];
  }

  return <Widget>[
    walletRow,
    _DetailRow(
      icon: Icons.payments_outlined,
      label: _prettyText(order.paymentMethod),
      value: '${remainder.toInrCurrency} • ${_prettyText(order.paymentStatus)}',
    ),
  ];
}

String _prettyText(String value) {
  return value.trim().toLowerCase().split('_').map((part) {
    if (part.isEmpty) {
      return '';
    }
    return '${part[0].toUpperCase()}${part.substring(1)}';
  }).join(' ');
}

String _readString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return fallback;
}
