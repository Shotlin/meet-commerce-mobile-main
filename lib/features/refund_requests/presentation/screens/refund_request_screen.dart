import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_shadows.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_entity.dart';
import 'package:bakaloo_flutter_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/domain/repositories/refund_request_repository.dart';
import 'package:bakaloo_flutter_app/features/refund_requests/presentation/providers/refund_request_provider.dart';

/// Shown after a customer opens a DELIVERED order and taps "Request Refund" —
/// pick which item(s) had a problem (or all of them), describe the issue,
/// and submit. Ends with a confirmation sheet setting the "our team will
/// connect within 24 hours" expectation, matching the Zomato/Swiggy-style
/// flow the product owner asked for.
class RefundRequestScreen extends ConsumerStatefulWidget {
  const RefundRequestScreen({required this.order, super.key});

  final OrderEntity order;

  @override
  ConsumerState<RefundRequestScreen> createState() =>
      _RefundRequestScreenState();
}

class _RefundRequestScreenState extends ConsumerState<RefundRequestScreen> {
  bool _allItems = false;
  late final Set<String> _selectedProductIds;
  final TextEditingController _descriptionController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedProductIds = <String>{};
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      (_allItems || _selectedProductIds.isNotEmpty) &&
      _descriptionController.text.trim().isNotEmpty;

  void _toggleAllItems(bool? value) {
    setState(() {
      _allItems = value ?? false;
      if (_allItems) {
        _selectedProductIds.clear();
      }
    });
  }

  void _toggleItem(String productId, bool? value) {
    setState(() {
      if (value ?? false) {
        _selectedProductIds.add(productId);
      } else {
        _selectedProductIds.remove(productId);
      }
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    final result = await ref.read(refundRequestProvider.notifier).createRequest(
          RefundRequestCreateParams(
            orderId: widget.order.id,
            itemScope: _allItems ? 'ALL' : 'SPECIFIC',
            description: _descriptionController.text.trim(),
            productIds: _allItems ? null : _selectedProductIds.toList(),
          ),
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
    });

    if (!result.isSuccess) {
      AppToast.show(context, result.failure!.message);
      return;
    }

    await _showConfirmation();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _showConfirmation() {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => const _RefundRequestSubmittedSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text('Request Refund', style: AppTextStyles.h2),
        actions: <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: TextButton(
              onPressed: (_submitting || !_canSubmit) ? null : _submit,
              child: _submitting
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Submit',
                      style: AppTextStyles.buttonMedium.copyWith(
                        color: _canSubmit
                            ? AppColors.primaryGreen
                            : AppColors.textDisabled,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
        children: <Widget>[
          Text(
            'What went wrong?',
            style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700),
          ),
          Gap(4.h),
          Text(
            'Select the item(s) that had a problem, or mark the whole order.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          Gap(12.h),
          _AllItemsTile(value: _allItems, onChanged: _toggleAllItems),
          Gap(10.h),
          ...widget.order.items.map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: _RefundItemTile(
                item: item,
                selected: _allItems || _selectedProductIds.contains(item.productId),
                enabled: !_allItems,
                onChanged: (value) => _toggleItem(item.productId, value),
              ),
            ),
          ),
          Gap(16.h),
          Text(
            'Describe the issue',
            style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700),
          ),
          Gap(8.h),
          TextField(
            controller: _descriptionController,
            maxLength: 1000,
            maxLines: 5,
            style: AppTextStyles.bodyMedium,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Tell us what happened — e.g. item damaged, missing, or wrong item delivered.',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllItemsTile extends StatelessWidget {
  const _AllItemsTile({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: value ? AppColors.orderVioletSurface : AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(
            color: value ? AppColors.orderViolet : AppColors.borderLight,
          ),
        ),
        child: Row(
          children: <Widget>[
            PhosphorIcon(
              PhosphorIcons.warningCircle,
              size: 22.sp,
              color: value ? AppColors.orderViolet : AppColors.textSecondary,
            ),
            Gap(10.w),
            Expanded(
              child: Text(
                'All items had a problem',
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: value ? AppColors.orderViolet : AppColors.textPrimary,
                ),
              ),
            ),
            Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.orderViolet,
            ),
          ],
        ),
      ),
    );
  }
}

class _RefundItemTile extends StatelessWidget {
  const _RefundItemTile({
    required this.item,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final OrderItemEntity item;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? () => onChanged(!selected) : null,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: Container(
          padding: EdgeInsets.all(10.w),
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
                decoration: BoxDecoration(
                  color: AppColors.bgSection,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                clipBehavior: Clip.antiAlias,
                child: (item.thumbnailUrl ?? '').isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.thumbnailUrl!,
                        memCacheWidth: 220,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Center(
                          child: PhosphorIcon(
                            PhosphorIcons.image,
                            color: AppColors.textDisabled,
                          ),
                        ),
                      )
                    : Center(
                        child: PhosphorIcon(
                          PhosphorIcons.image,
                          color: AppColors.textDisabled,
                        ),
                      ),
              ),
              Gap(10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Qty ${item.quantity} • ₹${item.total.toStringAsFixed(0)}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: selected,
                onChanged: enabled ? onChanged : null,
                activeColor: AppColors.orderViolet,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefundRequestSubmittedSheet extends StatelessWidget {
  const _RefundRequestSubmittedSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: EdgeInsets.all(16.w),
        padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 20.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          boxShadow: const <BoxShadow>[AppShadows.floatingShadow],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.elasticOut,
              builder: (context, value, child) => Transform.scale(
                scale: value,
                child: child,
              ),
              child: Container(
                width: 72.w,
                height: 72.w,
                decoration: const BoxDecoration(
                  color: AppColors.orderViolet,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40.sp,
                ),
              ),
            ),
            Gap(16.h),
            Text('Refund request submitted', style: AppTextStyles.h2),
            Gap(6.h),
            Text(
              "Our team will review your request and connect with you within 24 hours.",
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            Gap(18.h),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  minimumSize: Size.fromHeight(46.h),
                ),
                child: Text(
                  'Done',
                  style: AppTextStyles.buttonLarge.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
