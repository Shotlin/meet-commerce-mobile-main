import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CartSavingsBanner extends StatefulWidget {
  const CartSavingsBanner({
    required this.savingsTotal,
    super.key,
  });

  final double savingsTotal;

  @override
  State<CartSavingsBanner> createState() => _CartSavingsBannerState();
}

class _CartSavingsBannerState extends State<CartSavingsBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.savingsTotal <= 0) {
      return const SizedBox.shrink();
    }

    return Material(
      color: const Color(0xFFF0FFF4),
      child: InkWell(
        onTap: () {
          setState(() {
            _expanded = !_expanded;
          });
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF333333),
                          fontFamily: 'Inter',
                        ),
                        children: <InlineSpan>[
                          const TextSpan(text: 'Yay! You '),
                          TextSpan(
                            text:
                                'saved ₹${widget.savingsTotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0AC26B),
                              fontFamily: 'Inter',
                            ),
                          ),
                          const TextSpan(text: ' on this order'),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18.sp,
                    color: const Color(0xFF0AC26B),
                  ),
                ],
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: EdgeInsets.only(top: 10.h),
                  child: Text(
                    'MRP discounts and waived fees are already reflected in your total.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF4D4D4D),
                      height: 1.4,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
