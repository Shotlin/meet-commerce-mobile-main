import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/security/screenshot_prevention.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/payments/presentation/providers/payment_provider.dart';
import 'package:bakaloo_flutter_app/features/payments/presentation/service/razorpay_service.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:bakaloo_flutter_app/routing/app_router.dart';

class TopupScreen extends ConsumerStatefulWidget {
  const TopupScreen({super.key, this.initialAmount});

  /// Pre-fills the amount field — used when a caller (e.g. the checkout/cart
  /// wallet stripe's "Add Money" button) already knows exactly how much
  /// more the customer needs to fully cover their order.
  final double? initialAmount;

  @override
  ConsumerState<TopupScreen> createState() => _TopupScreenState();
}

class _TopupScreenState extends ConsumerState<TopupScreen> {
  final TextEditingController _amountController = TextEditingController();

  bool _isStarting = false;
  bool _isVerifying = false;
  String? _activeRazorpayOrderId;

  RazorpayService get _razorpayService => ref.read(razorpayServiceProvider);

  @override
  void initState() {
    super.initState();
    unawaited(ScreenshotPrevention.enable());
    _attachCallbacks();
    final initial = widget.initialAmount;
    if (initial != null && initial > 0) {
      _amountController.text = initial.ceil().toString();
    }
  }

  @override
  void dispose() {
    unawaited(ScreenshotPrevention.disable());
    _amountController.dispose();
    _razorpayService
      ..onSuccess = null
      ..onFailure = null
      ..onExternalWallet = null;
    super.dispose();
  }

  void _attachCallbacks() {
    _razorpayService
      ..onSuccess = (response) {
        unawaited(_verifyTopup(response));
      }
      ..onFailure = (_) {
        if (!mounted) {
          return;
        }
        AppToast.show(context, 'Payment cancelled or failed.');
      }
      ..onExternalWallet = () {};
  }

  Future<void> _startTopup() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      AppToast.show(context, '⚠️ Enter a valid amount', type: ToastType.warning);
      return;
    }
    if (!_razorpayService.isSupported) {
      AppToast.show(
        context,
        'Online payment checkout is not configured for this browser.',
        type: ToastType.warning,
      );
      return;
    }

    setState(() {
      _isStarting = true;
    });

    final result = await ref.read(walletProvider.notifier).createTopupOrder(
          amount,
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _isStarting = false;
    });

    if (!result.isSuccess || result.order == null) {
      AppToast.show(context, result.failure!.message);
      return;
    }

    final order = result.order!;
    final user = ref.read(currentUserProvider);
    _activeRazorpayOrderId = order.razorpayOrderId;

    try {
      _razorpayService.open(
        RazorpayOptions(
          key: order.key,
          amount: order.amount,
          razorpayOrderId: order.razorpayOrderId,
          name: 'Bakaloo',
          description: 'Wallet Top-up',
          contact: user?.phone,
          email: user?.email,
          prefillName: user?.name,
          themeColorHex: '#7C3AED',
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppToast.show(context, 'Unable to open Razorpay right now.');
    }
  }

  Future<void> _verifyTopup(RazorpayPaymentSuccess response) async {
    final paymentId = response.paymentId;
    final signature = response.signature;
    final orderId = _activeRazorpayOrderId;

    if (paymentId == null || signature == null || orderId == null) {
      if (!mounted) {
        return;
      }
      AppToast.show(context, 'Payment verification details missing.');
      return;
    }

    if (mounted) {
      setState(() {
        _isVerifying = true;
      });
    }

    final result = await ref.read(walletProvider.notifier).verifyTopup(
          WalletTopupVerifyParams(
            paymentId: paymentId,
            orderId: orderId,
            signature: signature,
          ),
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _isVerifying = false;
    });

    if (!result.isSuccess) {
      AppToast.show(context, result.failure!.message);
      return;
    }

    AppToast.show(context, '✅ Wallet top-up successful.', type: ToastType.success);
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text('Add Money', style: AppTextStyles.h2),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                boxShadow: const <BoxShadow>[AppShadows.cardShadow],
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: const BoxDecoration(
                      color: AppColors.orderVioletSurface,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: PhosphorIcon(
                        PhosphorIcons.wallet,
                        color: AppColors.orderViolet,
                        size: 20.sp,
                      ),
                    ),
                  ),
                  Gap(12.w),
                  Expanded(
                    child: Text(
                      'Add money securely with Razorpay',
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Gap(16.h),
            Text('Top-up amount', style: AppTextStyles.h3),
            Gap(8.h),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) {
                setState(() {});
              },
              decoration: const InputDecoration(
                hintText: 'Enter amount',
                prefixText: '₹ ',
              ),
            ),
            Gap(14.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: <double>[100, 250, 500, 1000].map((preset) {
                return ActionChip(
                  onPressed: () {
                    _amountController.text = preset.toStringAsFixed(0);
                    setState(() {});
                  },
                  backgroundColor: AppColors.bgCard,
                  side: const BorderSide(color: AppColors.borderLight),
                  label: Text(
                    preset.toInrCurrency,
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
            Gap(10.h),
            Text(
              'Amount will be charged in paise and credited after verification.',
              style: AppTextStyles.bodySmall,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isStarting || _isVerifying ? null : _startTopup,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orderViolet,
                  minimumSize: Size.fromHeight(50.h),
                ),
                child: _isStarting || _isVerifying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        amount > 0 ? 'Pay ${amount.toInrCurrency}' : 'Continue',
                        style: AppTextStyles.buttonLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            Gap(10.h),
          ],
        ),
      ),
    );
  }
}
