import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CartPillTab extends StatelessWidget {
  const CartPillTab({
    required this.tabs,
    required this.selectedIndex,
    required this.onTabChanged,
    super.key,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Row(
        children: List<Widget>.generate(
          tabs.length,
          (index) => Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: selectedIndex == index
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: selectedIndex == index
                      ? const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  tabs[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: selectedIndex == index
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: selectedIndex == index
                        ? const Color(0xFF222222)
                        : const Color(0xFF888888),
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
