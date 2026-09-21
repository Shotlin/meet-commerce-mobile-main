import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/constants/app_constants.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/entities/wallet_recipient_entity.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/recipient_search_provider.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:bakaloo_flutter_app/shared/widgets/confirmation_dialog.dart';

/// Search a recipient by phone, confirm, and send a wallet-to-wallet
/// transfer. Replaces the old raw-phone-entry transfer sheet — the operator
/// now sees the recipient's name before any money moves.
class SendMoneyScreen extends ConsumerStatefulWidget {
  const SendMoneyScreen({super.key});

  @override
  ConsumerState<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends ConsumerState<SendMoneyScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();

  WalletRecipientEntity? _selectedRecipient;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Defense-in-depth: the wallet screen no longer offers a way to reach
    // this screen while transfers are disabled, but bounce back immediately
    // if it's ever reached some other way (deep link, restored navigation
    // state) rather than let someone fill out a transfer that can only fail.
    if (!AppConstants.walletTransfersEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppToast.show(context, 'Wallet transfers are temporarily unavailable.');
        Navigator.of(context).maybePop();
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _selectRecipient(WalletRecipientEntity recipient) {
    setState(() {
      _selectedRecipient = recipient;
    });
  }

  void _changeRecipient() {
    setState(() {
      _selectedRecipient = null;
      _amountController.clear();
    });
  }

  Future<bool> _authenticateForTransfer() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) {
        return true;
      }

      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to transfer money',
        options: AuthenticationOptions(
          biometricOnly: canCheckBiometrics && availableBiometrics.isNotEmpty,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _send() async {
    final recipient = _selectedRecipient;
    if (recipient == null) {
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      AppToast.show(context, '⚠️ Enter a valid amount', type: ToastType.warning);
      return;
    }

    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Confirm transfer',
      message:
          'Send ${amount.toInrCurrency} to ${recipient.name} (${recipient.phone})?',
      confirmLabel: 'Send',
    );

    if (!mounted || confirmed != true) {
      return;
    }

    final didAuthenticate = await _authenticateForTransfer();
    if (!mounted) {
      return;
    }
    if (!didAuthenticate) {
      AppToast.show(context, 'Authentication required to send money.');
      return;
    }

    setState(() {
      _isSending = true;
    });

    final result = await ref.read(walletProvider.notifier).transfer(
          WalletTransferParams(phone: recipient.phone, amount: amount),
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSending = false;
    });

    if (!result.isSuccess) {
      AppToast.show(context, result.failure!.message);
      return;
    }

    AppToast.show(
      context,
      '✅ Sent ${amount.toInrCurrency} to ${recipient.name}.',
      type: ToastType.success,
    );
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text('Send Money', style: AppTextStyles.h2),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: _selectedRecipient == null
            ? _buildSearch()
            : _buildAmountEntry(_selectedRecipient!),
      ),
    );
  }

  Widget _buildSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Recipient\'s mobile number', style: AppTextStyles.h3),
        Gap(8.h),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          onChanged: (value) {
            ref
                .read(recipientSearchProvider.notifier)
                .onQueryChanged(value);
          },
          decoration: InputDecoration(
            hintText: 'Enter mobile number',
            prefixIcon: Padding(
              padding: EdgeInsets.all(12.w),
              child: PhosphorIcon(
                PhosphorIcons.magnifyingGlass,
                size: 20.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        Gap(16.h),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildResults() {
    final searchState = ref.watch(recipientSearchProvider);
    final query = _phoneController.text.trim();

    return searchState.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.orderViolet),
      ),
      error: (error, _) => Center(
        child: Text(
          error.toString().replaceFirst('Bad state: ', ''),
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.outOfStockRed,
          ),
        ),
      ),
      data: (recipients) {
        if (query.length < 6) {
          return Center(
            child: Text(
              'Enter at least 6 digits to search.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          );
        }
        if (recipients.isEmpty) {
          return Center(
            child: Text(
              'No Bakaloo user found with this number.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          );
        }
        return ListView.separated(
          itemCount: recipients.length,
          separatorBuilder: (_, __) => Gap(8.h),
          itemBuilder: (context, index) {
            final recipient = recipients[index];
            return InkWell(
              onTap: () => _selectRecipient(recipient),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              child: Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  boxShadow: const <BoxShadow>[AppShadows.cardShadow],
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: const BoxDecoration(
                        color: AppColors.orderVioletSurface,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: PhosphorIcon(
                          PhosphorIcons.user,
                          color: AppColors.orderViolet,
                          size: 18.sp,
                        ),
                      ),
                    ),
                    Gap(12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            recipient.name,
                            style: AppTextStyles.labelLarge.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(recipient.phone, style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAmountEntry(WalletRecipientEntity recipient) {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    return Column(
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
                    PhosphorIcons.user,
                    color: AppColors.orderViolet,
                    size: 20.sp,
                  ),
                ),
              ),
              Gap(12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      recipient.name,
                      style: AppTextStyles.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(recipient.phone, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              TextButton(
                onPressed: _changeRecipient,
                child: const Text('Change'),
              ),
            ],
          ),
        ),
        Gap(16.h),
        Text('Amount', style: AppTextStyles.h3),
        Gap(8.h),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Enter amount',
            prefixText: '₹ ',
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isSending ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orderViolet,
              minimumSize: Size.fromHeight(50.h),
            ),
            child: _isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    amount > 0 ? 'Send ${amount.toInrCurrency}' : 'Send',
                    style: AppTextStyles.buttonLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        Gap(10.h),
      ],
    );
  }
}
