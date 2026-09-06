import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

const Color _brandRed = Color(0xFFC32D2E);
const Color _chipBg = Color(0xFFF5F6F8);
const Color _chipText = Color(0xFF515968);

/// A single pill in [SearchFilterChipBar] — red-filled when selected,
/// neutral gray otherwise. Animates the swap over 180ms.
class SearchFilterChip extends StatelessWidget {
  const SearchFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 42.h,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _brandRed : _chipBg,
          borderRadius: BorderRadius.circular(21.r),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13.5.sp,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _chipText,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

/// Horizontally scrollable row of quick sub-filter chips for the search
/// results grid (e.g. "All / Fresh Chicken / Marinated / Boneless").
class SearchFilterChipBar extends StatelessWidget {
  const SearchFilterChipBar({
    required this.options,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (options.length <= 1) return const SizedBox.shrink();
    return SizedBox(
      height: 42.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => Gap(8.w),
        itemBuilder: (context, index) {
          final option = options[index];
          return SearchFilterChip(
            label: option,
            selected: option == selected,
            onTap: () => onSelected(option),
          );
        },
      ),
    );
  }
}

/// Compact "Sort by **Relevance** ⌄" pill matching the search-results
/// header. Tapping it is handled by the caller (opens the existing sort
/// bottom sheet).
class SearchSortButton extends StatelessWidget {
  const SearchSortButton({
    required this.currentLabel,
    required this.onTap,
    super.key,
  });

  final String currentLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 38.h,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11.r),
          border: Border.all(color: const Color(0xFFECEEF2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PhosphorIcon(
              PhosphorIcons.arrowsDownUp,
              size: 14.sp,
              color: const Color(0xFF6F7785),
            ),
            Gap(6.w),
            Text(
              'Sort by',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6F7785),
              ),
            ),
            Gap(4.w),
            Text(
              currentLabel,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111318),
              ),
            ),
            Gap(2.w),
            PhosphorIcon(
              PhosphorIcons.caretDownBold,
              size: 12.sp,
              color: const Color(0xFF111318),
            ),
          ],
        ),
      ),
    );
  }
}
