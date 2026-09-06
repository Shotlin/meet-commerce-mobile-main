import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:bakaloo_flutter_app/shared/widgets/expandable_section.dart';

class ProductVendorSection extends StatelessWidget {
  const ProductVendorSection({
    required this.vendorName,
    required this.vendorAddress,
    required this.vendorFssai,
    this.onExpand,
    super.key,
  });

  final String? vendorName;
  final String? vendorAddress;
  final String? vendorFssai;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final vendor = vendorName?.trim() ?? '';
    final address = vendorAddress?.trim() ?? '';
    final fssai = vendorFssai?.trim() ?? '';

    if (vendor.isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpandableSection(
      title: 'Vendor Details',
      initiallyExpanded: false,
      topBorder: true,
      titleFontSize: 15.sp,
      titleWeight: FontWeight.w600,
      titleHeight: 1.4,
      onToggle: onExpand,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _VendorDetailBlock(
              label: 'Vendor',
              value: vendor,
            ),
            if (address.isNotEmpty) SizedBox(height: 8.h),
            if (address.isNotEmpty)
              _VendorDetailBlock(
                label: 'Address',
                value: address,
              ),
            if (fssai.isNotEmpty) SizedBox(height: 8.h),
            if (fssai.isNotEmpty)
              _VendorDetailBlock(
                label: 'FSSAI License',
                value: fssai,
              ),
          ],
        ),
      ),
    );
  }
}

class _VendorDetailBlock extends StatelessWidget {
  const _VendorDetailBlock({
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
            fontWeight: FontWeight.w500,
            color: const Color(0xFF999999),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF333333),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
