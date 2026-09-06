import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/shared/widgets/expandable_section.dart';

class ProductDetailsSection extends StatelessWidget {
  const ProductDetailsSection({
    required this.attributes,
    this.onExpand,
    super.key,
  });

  final List<Map<String, dynamic>> attributes;
  final VoidCallback? onExpand;

  List<Map<String, String>> get _normalizedAttributes {
    return attributes
        .map((attribute) {
          final label = '${attribute['label'] ?? ''}'.trim();
          final value = '${attribute['value'] ?? ''}'.trim();
          if (label.isEmpty || value.isEmpty) {
            return null;
          }
          return <String, String>{
            'label': label,
            'value': value,
          };
        })
        .whereType<Map<String, String>>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _normalizedAttributes;
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpandableSection(
      title: 'Product Details',
      initiallyExpanded: true,
      titleFontSize: 17.sp,
      titleWeight: FontWeight.w700,
      titleHeight: 1.2,
      onToggle: onExpand,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Column(
          children: <Widget>[
            for (int i = 0; i < items.length; i += 2)
              Padding(
                padding: EdgeInsets.only(bottom: 20.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _AttributeCell(
                        label: items[i]['label']!,
                        value: items[i]['value']!,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: i + 1 < items.length
                          ? _AttributeCell(
                              label: items[i + 1]['label']!,
                              value: items[i + 1]['value']!,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AttributeCell extends StatelessWidget {
  const _AttributeCell({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF333333),
            height: 1.3,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.sp,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF666666),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
