import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/constants/app_constants.dart';
import 'package:bakaloo_flutter_app/core/security/screenshot_prevention.dart';
import 'package:bakaloo_flutter_app/core/security/device_authentication.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/datetime_extensions.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/entities/transaction_entity.dart';
import 'package:bakaloo_flutter_app/features/wallet/domain/entities/wallet_entity.dart';
import 'package:bakaloo_flutter_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  static const int _pageSize = 20;

  final DeviceAuthentication _deviceAuthentication = DeviceAuthentication();
  late final PagingController<int, TransactionEntity> _pagingController;

  WalletTransactionFilter _filter = WalletTransactionFilter.all;
  bool _balanceUnlocked = false;
  bool _isAuthenticating = true;

  @override
  void initState() {
    super.initState();
    unawaited(ScreenshotPrevention.enable());
    _pagingController = PagingController<int, TransactionEntity>(
      firstPageKey: 1,
    )..addPageRequestListener(_fetchPage);
    unawaited(_authenticateForBalance());
    // Balance changes made outside this app (admin credit, refund, cashback
    // payout, a topup approved late) never invalidate the keepAlive
    // walletProvider on their own — refetch every time this screen opens
    // rather than trusting whatever was cached from earlier in the session.
    unawaited(ref.read(walletProvider.notifier).refreshWallet());
  }

  @override
  void dispose() {
    unawaited(ScreenshotPrevention.disable());
    _pagingController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int pageKey) async {
    final result = await ref.read(walletProvider.notifier).getTransactionsPage(
          page: pageKey,
          limit: _pageSize,
          filter: _filter,
        );

    result.fold(
      (failure) {
        _pagingController.error = failure.message;
      },
      (data) {
        final isLastPage = data.pagination.totalPages <= pageKey ||
            data.transactions.length < _pageSize;
        if (isLastPage) {
          _pagingController.appendLastPage(data.transactions);
          return;
        }
        _pagingController.appendPage(data.transactions, pageKey + 1);
      },
    );
  }

  Future<void> _authenticateForBalance() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isAuthenticating = true;
    });

    bool unlocked = false;
    String? failureMessage;
    try {
      unlocked = await _deviceAuthentication.authenticateIfAvailable(
        reason: 'Authenticate to view your wallet balance',
      );
    } catch (_) {
      failureMessage = 'Authentication failed. Please try again.';
      unlocked = false;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _balanceUnlocked = unlocked;
      _isAuthenticating = false;
    });

    if (!unlocked && failureMessage != null) {
      _showSnack(failureMessage);
    }
  }

  Future<void> _openTopup() async {
    final completed = await context.push<bool>(RouteNames.topup);
    if (!mounted || completed != true) {
      return;
    }

    await ref.read(walletProvider.notifier).refreshWallet();
    _pagingController.refresh();
  }

  Future<void> _openSendMoney() async {
    final completed = await context.push<bool>(RouteNames.walletSend);
    if (!mounted || completed != true) {
      return;
    }

    await ref.read(walletProvider.notifier).refreshWallet();
    _pagingController.refresh();
  }

  Future<void> _refreshAll() async {
    await ref.read(walletProvider.notifier).refreshWallet();
    _pagingController.refresh();
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletProvider);
    // `.value`, not `.asData?.value` — keeps the last known wallet visible
    // through a reload instead of dropping back to the full-screen spinner
    // (`.asData` is null during AsyncLoading even when it's carrying a
    // previous value forward).
    final wallet = walletAsync.value;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text('Bakaloo Wallet', style: AppTextStyles.h2),
      ),
      body: walletAsync.when(
        loading: () => wallet == null
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.orderViolet,
                ),
              )
            : _buildContent(wallet),
        error: (error, _) => wallet == null
            ? _WalletErrorState(
                message: error.toString().replaceFirst('Bad state: ', ''),
                onRetry: () => ref.invalidate(walletProvider),
              )
            : _buildContent(wallet),
        data: _buildContent,
      ),
    );
  }

  Widget _buildContent(WalletEntity wallet) {
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
          child: Column(
            children: <Widget>[
              _BalanceCard(
                balance: wallet.balance,
                unlocked: _balanceUnlocked,
                isAuthenticating: _isAuthenticating,
                onUnlock: _authenticateForBalance,
                onAddMoney: _openTopup,
                onTransfer: _openSendMoney,
              ),
              Gap(14.h),
              _QuickActionRow(
                onAddMoney: _openTopup,
                onTransfer: _openSendMoney,
                onHistory: _pagingController.refresh,
              ),
              Gap(14.h),
              _TransactionFilterChips(
                selected: _filter,
                onChanged: (value) {
                  if (_filter == value) {
                    return;
                  }
                  setState(() {
                    _filter = value;
                  });
                  _pagingController.refresh();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.orderViolet,
            onRefresh: _refreshAll,
            child: PagedListView<int, TransactionEntity>(
              pagingController: _pagingController,
              padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 24.h),
              physics: const AlwaysScrollableScrollPhysics(),
              builderDelegate: PagedChildBuilderDelegate<TransactionEntity>(
                itemBuilder: (context, transaction, index) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: _TransactionTile(transaction: transaction),
                  );
                },
                firstPageProgressIndicatorBuilder: (_) => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.orderViolet,
                  ),
                ),
                newPageProgressIndicatorBuilder: (_) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.orderViolet,
                    ),
                  ),
                ),
                firstPageErrorIndicatorBuilder: (_) => _WalletErrorState(
                  message: _pagingController.error?.toString() ??
                      'Unable to load transactions.',
                  onRetry: _pagingController.refresh,
                ),
                noItemsFoundIndicatorBuilder: (_) => _EmptyTransactionsState(
                  filter: _filter,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.unlocked,
    required this.isAuthenticating,
    required this.onUnlock,
    required this.onAddMoney,
    required this.onTransfer,
  });

  final double balance;
  final bool unlocked;
  final bool isAuthenticating;
  final Future<void> Function() onUnlock;
  final VoidCallback onAddMoney;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    final Widget amountText = Text(
      unlocked ? balance.toInrCurrency : '₹••••',
      style: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w800,
        color: const Color(0xFF1A1A1A),
        fontSize: 34.sp,
        height: 1.1,
      ),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.orderCardBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0x0F000000),
            blurRadius: 12.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Wallet balance',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Gap(8.h),
                    Row(
                      children: <Widget>[
                        Flexible(child: amountText),
                        Gap(10.w),
                        _HideBalanceButton(
                          unlocked: unlocked,
                          isAuthenticating: isAuthenticating,
                          onTap: onUnlock,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const _WalletGlyph(),
            ],
          ),
          Gap(18.h),
          Row(
            children: <Widget>[
              Expanded(
                child: _WalletActionButton(
                  icon: PhosphorIcons.plusBold,
                  label: 'Add Money',
                  filled: true,
                  onTap: onAddMoney,
                ),
              ),
              if (AppConstants.walletTransfersEnabled) ...<Widget>[
                Gap(12.w),
                Expanded(
                  child: _WalletActionButton(
                    icon: PhosphorIcons.arrowsClockwise,
                    label: 'Transfer',
                    filled: false,
                    onTap: onTransfer,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Small circular hide/show-balance button next to the amount.
class _HideBalanceButton extends StatelessWidget {
  const _HideBalanceButton({
    required this.unlocked,
    required this.isAuthenticating,
    required this.onTap,
  });

  final bool unlocked;
  final bool isAuthenticating;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isAuthenticating ? null : () => onTap(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30.w,
        height: 30.w,
        decoration: const BoxDecoration(
          color: AppColors.orderVioletSurface,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: isAuthenticating
              ? SizedBox(
                  width: 14.w,
                  height: 14.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.orderViolet),
                  ),
                )
              : PhosphorIcon(
                  unlocked ? PhosphorIcons.eye : PhosphorIcons.eyeSlash,
                  size: 16.sp,
                  color: AppColors.orderViolet,
                ),
        ),
      ),
    );
  }
}

/// Decorative wallet glyph on the right of the balance card. Swap for a real
/// 3D illustration asset by replacing this widget with an Image.asset.
class _WalletGlyph extends StatelessWidget {
  const _WalletGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64.w,
      height: 64.w,
      decoration: BoxDecoration(
        color: AppColors.orderVioletSurface,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Center(
        child: PhosphorIcon(
          PhosphorIcons.walletFill,
          size: 32.sp,
          color: AppColors.orderViolet,
        ),
      ),
    );
  }
}

class _WalletActionButton extends StatelessWidget {
  const _WalletActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final PhosphorIconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.orderViolet : AppColors.bgCard,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          height: 48.h,
          alignment: Alignment.center,
          decoration: filled
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.orderViolet, width: 1.4),
                ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PhosphorIcon(
                icon,
                size: 16.sp,
                color: filled ? Colors.white : AppColors.orderViolet,
              ),
              Gap(8.w),
              Text(
                label,
                style: AppTextStyles.buttonMedium.copyWith(
                  color: filled ? Colors.white : AppColors.orderViolet,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({
    required this.onAddMoney,
    required this.onTransfer,
    required this.onHistory,
  });

  final VoidCallback onAddMoney;
  final VoidCallback onTransfer;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        _QuickActionCircle(
          icon: PhosphorIcons.plusCircle,
          label: 'Add',
          onTap: onAddMoney,
        ),
        if (AppConstants.walletTransfersEnabled)
          _QuickActionCircle(
            icon: PhosphorIcons.arrowsLeftRight,
            label: 'Transfer',
            onTap: onTransfer,
          ),
        _QuickActionCircle(
          icon: PhosphorIcons.clockCounterClockwise,
          label: 'History',
          onTap: onHistory,
        ),
      ],
    );
  }
}

class _QuickActionCircle extends StatelessWidget {
  const _QuickActionCircle({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final PhosphorIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      child: Column(
        children: <Widget>[
          Container(
            width: 56.w,
            height: 56.w,
            decoration: const BoxDecoration(
              color: AppColors.orderVioletSurface,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: PhosphorIcon(
                icon,
                color: AppColors.orderViolet,
                size: 22.sp,
              ),
            ),
          ),
          Gap(6.h),
          Text(label, style: AppTextStyles.labelLarge),
        ],
      ),
    );
  }
}

class _TransactionFilterChips extends StatelessWidget {
  const _TransactionFilterChips({
    required this.selected,
    required this.onChanged,
  });

  final WalletTransactionFilter selected;
  final ValueChanged<WalletTransactionFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: WalletTransactionFilter.values.map((filter) {
        final isSelected = selected == filter;
        return Padding(
          padding: EdgeInsets.only(right: 8.w),
          child: ChoiceChip(
            selected: isSelected,
            onSelected: (_) => onChanged(filter),
            label: Text(
              filter.label,
              style: AppTextStyles.labelLarge.copyWith(
                color:
                    isSelected ? AppColors.orderViolet : AppColors.textPrimary,
              ),
            ),
            selectedColor: AppColors.orderVioletSurface,
            backgroundColor: AppColors.bgCard,
            side: BorderSide(
              color: isSelected ? AppColors.orderViolet : AppColors.borderLight,
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
  });

  final TransactionEntity transaction;

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.type == WalletTransactionType.CREDIT;
    final color = isCredit ? AppColors.successGreen : AppColors.outOfStockRed;

    return Container(
      padding: EdgeInsets.all(14.w),
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
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: PhosphorIcon(
                isCredit ? PhosphorIcons.arrowDown : PhosphorIcons.arrowUp,
                color: color,
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
                  transaction.description,
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Gap(2.h),
                Text(
                  transaction.createdAt.toIndianDateTime,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}${transaction.amount.toInrCurrency}',
            style: AppTextStyles.h3.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _WalletErrorState extends StatelessWidget {
  const _WalletErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            Gap(10.h),
            FilledButton(
              onPressed: onRetry,
              child: Text('Retry', style: AppTextStyles.buttonMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTransactionsState extends StatelessWidget {
  const _EmptyTransactionsState({
    required this.filter,
  });

  final WalletTransactionFilter filter;

  @override
  Widget build(BuildContext context) {
    final label = switch (filter) {
      WalletTransactionFilter.all => 'transactions',
      WalletTransactionFilter.credit => 'credit transactions',
      WalletTransactionFilter.debit => 'debit transactions',
    };

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Text(
          'No $label found yet.',
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
