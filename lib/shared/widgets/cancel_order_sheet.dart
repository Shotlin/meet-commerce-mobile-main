import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';

/// The fixed set of cancellation reasons offered to the customer, in the
/// order shown. Sent verbatim as the backend's `reason` string when picked
/// — since the client only ever sends one of these five strings (or the
/// `OTHER: `-prefixed free text below), they act as a de-facto enum for
/// future analytics with no backend schema change. Treat any future wording
/// edit as retiring this string and adding a new one, never rewording in
/// place, so historical rows don't silently change meaning.
const List<String> _kCancelReasons = <String>[
  'Delivery is taking too long',
  'Changed my mind',
  'Found a better price elsewhere',
  'Ordered by mistake',
  'Wrong address or items selected',
];

const String _kOtherOption = 'Other';
const int _kOtherMaxLength = 490;

/// Mandatory reason-picker + review confirmation shown before a customer's
/// order cancellation actually goes through — matches the Zomato/Swiggy
/// pattern of asking why, rather than the previous plain Yes/No dialog
/// ([ConfirmationDialog], still used elsewhere and left untouched).
///
/// Returns `null` if the customer backs out at any point (close button,
/// swipe-dismiss, "Keep Order"). Returns the resolved reason string —
/// ready to pass straight through as `CancelOrderUseCase`'s `reason` —
/// only once both steps are completed with "Yes, Cancel Order".
class CancelOrderSheet extends StatefulWidget {
  const CancelOrderSheet({required this.orderNumber, super.key});

  final String orderNumber;

  static Future<String?> show(
    BuildContext context, {
    required String orderNumber,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CancelOrderSheet(orderNumber: orderNumber),
    );
  }

  @override
  State<CancelOrderSheet> createState() => _CancelOrderSheetState();
}

class _CancelOrderSheetState extends State<CancelOrderSheet> {
  int _step = 0;
  String? _selectedReason;
  final TextEditingController _otherController = TextEditingController();

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  bool get _isOtherSelected => _selectedReason == _kOtherOption;

  /// The final reason string to send, or `null` while incomplete (no
  /// reason picked yet, or "Other" picked but nothing typed) — this is
  /// what gates the Step 1 "Continue" button being enabled.
  String? get _resolvedReason {
    if (_selectedReason == null) {
      return null;
    }
    if (!_isOtherSelected) {
      return _selectedReason;
    }
    final text = _otherController.text.trim();
    return text.isEmpty ? null : 'OTHER: $text';
  }

  void _selectReason(String reason) {
    setState(() => _selectedReason = reason);
  }

  void _goToReview() {
    if (_resolvedReason == null) {
      return;
    }
    setState(() => _step = 1);
  }

  void _goBackToPicker() {
    setState(() => _step = 0);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppDimensions.spacing24,
          right: AppDimensions.spacing24,
          top: AppDimensions.spacing8,
          bottom: AppDimensions.spacing24 +
              MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _step == 0 ? _buildPicker() : _buildReview(),
        ),
      ),
    );
  }

  Widget _buildPicker() {
    return Column(
      key: const ValueKey('picker'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Cancel Order?', style: AppTextStyles.h2),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        Text(
          "Tell us why you're cancelling ${widget.orderNumber}",
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
        const Gap(AppDimensions.spacing16),
        ..._kCancelReasons.map(
          (reason) => Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.spacing8),
            child: _ReasonRow(
              label: reason,
              selected: _selectedReason == reason,
              onTap: () => _selectReason(reason),
            ),
          ),
        ),
        _ReasonRow(
          label: _kOtherOption,
          selected: _isOtherSelected,
          onTap: () => _selectReason(_kOtherOption),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 150),
          child: _isOtherSelected
              ? Padding(
                  padding: const EdgeInsets.only(
                    top: AppDimensions.spacing8,
                  ),
                  child: TextField(
                    controller: _otherController,
                    maxLength: _kOtherMaxLength,
                    maxLines: 3,
                    minLines: 2,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Please tell us more (required)',
                      filled: true,
                      fillColor: AppColors.bgInput,
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        const Gap(AppDimensions.spacing16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _resolvedReason == null ? null : _goToReview,
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }

  Widget _buildReview() {
    final reason = _resolvedReason ?? '';
    final displayReason =
        reason.startsWith('OTHER: ') ? reason.substring(7) : reason;

    return Column(
      key: const ValueKey('review'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _goBackToPicker,
            ),
            Expanded(
              child: Text('Confirm Cancellation', style: AppTextStyles.h2),
            ),
          ],
        ),
        const Gap(AppDimensions.spacing12),
        _ReviewRow(label: 'Order', value: widget.orderNumber),
        const Gap(AppDimensions.spacing8),
        _ReviewRow(label: 'Reason', value: displayReason),
        const Gap(AppDimensions.spacing20),
        Container(
          padding: const EdgeInsets.all(AppDimensions.spacing12),
          decoration: BoxDecoration(
            color: AppColors.errorRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.errorRed,
                size: 20,
              ),
              const Gap(AppDimensions.spacing8),
              Expanded(
                child: Text(
                  'This action cannot be undone. Your order will be '
                  'cancelled immediately.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.errorRed),
                ),
              ),
            ],
          ),
        ),
        const Gap(AppDimensions.spacing24),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Keep Order'),
              ),
            ),
            const Gap(AppDimensions.spacing12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.errorRed,
                ),
                onPressed: () => Navigator.of(context).pop(reason),
                child: const Text('Yes, Cancel Order'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
          vertical: AppDimensions.spacing12,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryGreenLight
              : AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: selected ? AppColors.primaryGreen : AppColors.borderLight,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected
                      ? AppColors.primaryGreenDark
                      : AppColors.textPrimary,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primaryGreen,
                size: 20,
              )
            else
              const Icon(
                Icons.circle_outlined,
                color: AppColors.borderLight,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondary),
        ),
        const Gap(AppDimensions.spacing4),
        Text(
          value,
          style: AppTextStyles.labelLarge
              .copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
