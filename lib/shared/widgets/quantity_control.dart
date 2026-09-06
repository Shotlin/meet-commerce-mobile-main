import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_dimensions.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';

class QuantityControl extends StatefulWidget {
  const QuantityControl({
    required this.quantity,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
    this.width = 88,
    this.height = 36,
    this.disableIncrement = false,
    super.key,
  });

  final int quantity;
  final VoidCallback? onAdd;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final double width;
  final double height;
  // Purchase-limits: greys out (and visually suppresses ripple on) the
  // "ADD"/"+" affordance when this product is at its limit. onAdd/
  // onIncrement stay wired regardless of this flag — the actual
  // block-and-toast happens at the call site, this only controls the
  // affordance so a stale cache can still be caught (and toasted) instead
  // of the tap silently doing nothing.
  final bool disableIncrement;

  @override
  State<QuantityControl> createState() => _QuantityControlState();
}

class _QuantityControlState extends State<QuantityControl> {
  double _countScale = 1;

  @override
  void didUpdateWidget(covariant QuantityControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quantity != widget.quantity && widget.quantity > 0) {
      setState(() {
        _countScale = 1.2;
      });
      Future<void>.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _countScale = 1;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAddState = widget.quantity <= 0;

    return SizedBox(
      width: widget.width.w,
      height: widget.height.h,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: isAddState
            ? _AddButton(
                key: const ValueKey<String>('add-state'),
                onTap: widget.onAdd,
                disabled: widget.disableIncrement,
              )
            : _QtySelector(
                key: ValueKey<int>(widget.quantity),
                quantity: widget.quantity,
                countScale: _countScale,
                onIncrement: widget.onIncrement,
                onDecrement: widget.onDecrement,
                disableIncrement: widget.disableIncrement,
              ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.onTap,
    this.disabled = false,
    super.key,
  });

  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primaryGreen),
          backgroundColor: AppColors.bgCard,
          foregroundColor: AppColors.primaryGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          padding: EdgeInsets.zero,
          overlayColor: disabled ? Colors.transparent : null,
        ),
        child: Text(
          'ADD',
          style: AppTextStyles.buttonSmall.copyWith(
            color: AppColors.primaryGreen,
          ),
        ),
      ),
    );
  }
}

class _QtySelector extends StatelessWidget {
  const _QtySelector({
    required this.quantity,
    required this.countScale,
    required this.onIncrement,
    required this.onDecrement,
    this.disableIncrement = false,
    super.key,
  });

  final int quantity;
  final double countScale;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final bool disableIncrement;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          _IconTapButton(
            icon: PhosphorIcons.minus,
            onTap: onDecrement,
          ),
          Expanded(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              scale: countScale,
              child: Center(
                child: Text(
                  '$quantity',
                  style: AppTextStyles.buttonSmall.copyWith(
                    color: AppColors.textOnGreen,
                  ),
                ),
              ),
            ),
          ),
          _IconTapButton(
            icon: PhosphorIcons.plus,
            onTap: onIncrement,
            disabled: disableIncrement,
          ),
        ],
      ),
    );
  }
}

class _IconTapButton extends StatelessWidget {
  const _IconTapButton({
    required this.icon,
    required this.onTap,
    this.disabled = false,
  });

  final PhosphorIconData icon;
  final VoidCallback? onTap;
  // Purely visual — onTap always stays wired so a stale cache can still
  // be caught (and toasted) at the call site instead of the tap silently
  // doing nothing.
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      splashColor: disabled ? Colors.transparent : null,
      highlightColor: disabled ? Colors.transparent : null,
      child: SizedBox(
        width: 26.w,
        child: Center(
          child: Opacity(
            opacity: disabled ? 0.4 : 1,
            child: PhosphorIcon(
              icon,
              size: 15,
              color: AppColors.textOnGreen,
            ),
          ),
        ),
      ),
    );
  }
}
