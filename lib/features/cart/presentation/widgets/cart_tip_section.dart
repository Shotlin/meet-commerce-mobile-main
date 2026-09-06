import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:bakaloo_flutter_app/features/cart/domain/entities/tip_preset_entity.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/providers/cart_enhancement_providers.dart';
import 'package:bakaloo_flutter_app/features/cart/presentation/widgets/cart_pill_tab.dart';

class CartTipSection extends ConsumerStatefulWidget {
  const CartTipSection({super.key});

  @override
  ConsumerState<CartTipSection> createState() => _CartTipSectionState();
}

class _CartTipSectionState extends ConsumerState<CartTipSection> {
  static const List<String> _tabs = <String>[
    'Give a Tip',
    'Delivery Instructions',
  ];
  static const List<TipPresetEntity> _fallbackTipPresets = <TipPresetEntity>[
    TipPresetEntity(amount: 10, emoji: '🍵'),
    TipPresetEntity(amount: 35, emoji: '🔥'),
    TipPresetEntity(amount: 50, emoji: '🤩'),
  ];
  static const List<String> _instructionPresets = <String>[
    'Leave at door',
    'Don\'t ring bell',
    'Call when nearby',
  ];

  late final TextEditingController _instructionsController;
  Timer? _tipDebounce;
  Timer? _instructionsDebounce;
  int _selectedTabIndex = 0;
  double _draftTipAmount = 0;

  @override
  void initState() {
    super.initState();
    _draftTipAmount = ref.read(cartTipProvider);
    _instructionsController = TextEditingController(
      text: ref.read(deliveryInstructionsProvider),
    );
  }

  @override
  void dispose() {
    _tipDebounce?.cancel();
    _instructionsDebounce?.cancel();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen<double>(cartTipProvider, (previous, next) {
        if ((_tipDebounce?.isActive ?? false) || next == _draftTipAmount) {
          return;
        }
        if (!mounted) {
          return;
        }
        setState(() {
          _draftTipAmount = next;
        });
      })
      ..listen<String>(deliveryInstructionsProvider, (previous, next) {
        if ((_instructionsDebounce?.isActive ?? false) ||
            next == _instructionsController.text) {
          return;
        }
        _instructionsController.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
        if (mounted) {
          setState(() {});
        }
      });

    final tipPresetsAsync = ref.watch(tipPresetsProvider);

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 18.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CartPillTab(
            tabs: _tabs,
            selectedIndex: _selectedTabIndex,
            onTabChanged: (index) {
              setState(() {
                _selectedTabIndex = index;
              });
            },
          ),
          Gap(18.h),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _selectedTabIndex == 0
                ? _buildTipTab(context, tipPresetsAsync)
                : _buildInstructionsTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTipTab(
    BuildContext context,
    AsyncValue<List<TipPresetEntity>> tipPresetsAsync,
  ) {
    return KeyedSubtree(
      key: const ValueKey<String>('tip-tab'),
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
                      'Tip Delivery Partner',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF222222),
                        fontFamily: 'Inter',
                      ),
                    ),
                    Gap(8.h),
                    Text(
                      'Help them earn a little extra for their effort. 100% of this tip will go to them.',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF666666),
                        height: 1.4,
                        fontFamily: 'Inter',
                      ),
                    ),
                    Gap(10.h),
                    InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'All tip payments go directly to your delivery partner.',
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'Delivery Partner Safety',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF666666),
                          decoration: TextDecoration.underline,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Container(
                width: 80.w,
                height: 60.h,
                alignment: Alignment.topRight,
                child: Text(
                  '🛵',
                  style: TextStyle(fontSize: 44.sp),
                ),
              ),
            ],
          ),
          Gap(18.h),
          tipPresetsAsync.when(
            loading: () => _buildTipLoadingRow(),
            error: (_, __) => _buildTipPresetRow(_fallbackTipPresets),
            data: (presets) => _buildTipPresetRow(
              presets.isEmpty ? _fallbackTipPresets : presets,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipPresetRow(List<TipPresetEntity> presets) {
    final visiblePresets = presets.take(3).toList(growable: false);
    final selectedIndex = _selectedTipIndex(visiblePresets);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: <Widget>[
          ...List<Widget>.generate(
            visiblePresets.length,
            (index) => Padding(
              padding: EdgeInsets.only(
                right: index == visiblePresets.length - 1 ? 0 : 10.w,
              ),
              child: _TipChip(
                emoji: visiblePresets[index].emoji ?? '✨',
                label: '₹${visiblePresets[index].amount.toStringAsFixed(0)}',
                selected: selectedIndex == index,
                onTap: () {
                  final double nextAmount =
                      selectedIndex == index ? 0 : visiblePresets[index].amount;
                  _setTipAmount(nextAmount);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipLoadingRow() {
    return Wrap(
      spacing: 10.w,
      runSpacing: 10.h,
      children: List<Widget>.generate(
        4,
        (_) => Container(
          width: 82.w,
          height: 44.h,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(24.r),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionsTab() {
    return KeyedSubtree(
      key: const ValueKey<String>('instructions-tab'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _instructionsController,
            maxLines: 3,
            minLines: 3,
            maxLength: 200,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            scrollPadding: EdgeInsets.only(bottom: 160.h),
            onChanged: _setInstructions,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF222222),
              fontFamily: 'Inter',
            ),
            decoration: InputDecoration(
              hintText: 'Add delivery instructions...',
              hintStyle: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: const Color(0xFFBBBBBB),
                fontFamily: 'Inter',
              ),
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.all(14.w),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(
                  color: Color(0xFFE23372),
                  width: 1.2,
                ),
              ),
            ),
          ),
          Gap(12.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: _instructionPresets
                .map(
                  (preset) => ActionChip(
                    onPressed: () => _appendInstruction(preset),
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    backgroundColor: Colors.white,
                    label: Text(
                      preset,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF555555),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          Gap(10.h),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_instructionsController.text.length}/200',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF999999),
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _selectedTipIndex(List<TipPresetEntity> presets) {
    final presetIndex = presets.indexWhere(
      (preset) => preset.amount == _draftTipAmount,
    );
    if (presetIndex != -1) {
      return presetIndex;
    }
    if (_draftTipAmount > 0) {
      return presets.length;
    }
    return -1;
  }

  void _setTipAmount(double amount) {
    setState(() {
      _draftTipAmount = amount;
    });

    _tipDebounce?.cancel();
    _tipDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(ref.read(cartTipProvider.notifier).setTip(amount));
    });
  }

  void _setInstructions(String value) {
    setState(() {});
    _instructionsDebounce?.cancel();
    _instructionsDebounce = Timer(const Duration(milliseconds: 800), () {
      unawaited(
        ref.read(deliveryInstructionsProvider.notifier).setInstructions(value),
      );
    });
  }

  void _appendInstruction(String preset) {
    final current = _instructionsController.text.trim();
    final separator =
        current.isEmpty ? '' : (current.endsWith('.') ? ' ' : '. ');
    final nextValue = '$current$separator$preset';
    final clamped =
        nextValue.length > 200 ? nextValue.substring(0, 200) : nextValue;

    _instructionsController.value = TextEditingValue(
      text: clamped,
      selection: TextSelection.collapsed(offset: clamped.length),
    );
    _setInstructions(clamped);
  }

  Future<double?> _showCustomTipSheet(BuildContext context) async {
    final initialAmount = _draftTipAmount > 0 &&
            _draftTipAmount % 1 == 0 &&
            _draftTipAmount <= 500
        ? _draftTipAmount.toStringAsFixed(0)
        : '';
    final controller = TextEditingController(text: initialAmount);

    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24.r),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final parsed = double.tryParse(controller.text.trim());
            final isValid = parsed != null && parsed >= 1 && parsed <= 500;

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16.w,
                  20.h,
                  16.w,
                  MediaQuery.of(context).viewInsets.bottom + 20.h,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Add custom tip',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF222222),
                        fontFamily: 'Inter',
                      ),
                    ),
                    Gap(8.h),
                    Text(
                      'Enter an amount between ₹1 and ₹500.',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF666666),
                        height: 1.4,
                        fontFamily: 'Inter',
                      ),
                    ),
                    Gap(16.h),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        hintText: 'Enter tip amount',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide:
                              const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: const BorderSide(
                            color: Color(0xFFE23372),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                    Gap(16.h),
                    SizedBox(
                      width: double.infinity,
                      height: 52.h,
                      child: ElevatedButton(
                        onPressed: isValid
                            ? () => Navigator.of(context).pop(parsed)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE23372),
                          disabledBackgroundColor: const Color(0xFFE8E8E8),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: const Color(0xFF888888),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        child: Text(
                          'Apply Tip',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                          ),
                        ),
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

    return result;
  }
}

class _TipChip extends StatelessWidget {
  const _TipChip({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0F0F0) : Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: selected ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              emoji,
              style: TextStyle(fontSize: 16.sp),
            ),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF222222),
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
