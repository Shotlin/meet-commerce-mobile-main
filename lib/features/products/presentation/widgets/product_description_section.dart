import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/shared/widgets/expandable_section.dart';

class ProductDescriptionSection extends StatelessWidget {
  const ProductDescriptionSection({
    required this.description,
    this.onExpand,
    super.key,
  });

  final String? description;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final value = description?.trim() ?? '';
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpandableSection(
      title: 'Product Description',
      initiallyExpanded: false,
      topBorder: true,
      titleFontSize: 15.sp,
      titleWeight: FontWeight.w600,
      titleHeight: 1.4,
      onToggle: onExpand,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF333333),
            height: 1.6,
          ),
        ),
      ),
    );
  }
}
