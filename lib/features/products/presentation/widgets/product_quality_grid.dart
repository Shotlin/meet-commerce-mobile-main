import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Bakaloo's standing quality promise — the same four claims on every
/// product page (cold-chain, protein, FSSAI, freshness), not a
/// per-product attribute, so it's rendered as static brand copy rather
/// than sourced from product data.
class ProductQualityGrid extends StatelessWidget {
  const ProductQualityGrid({super.key});

  static const List<_QualityItem> _items = <_QualityItem>[
    _QualityItem(
      icon: PhosphorIcons.snowflakeBold,
      label: 'Maintained\nat 0-4°C',
    ),
    _QualityItem(
      icon: PhosphorIcons.leafBold,
      label: 'Protein Rich\n& Low Fat',
    ),
    _QualityItem(
      icon: PhosphorIcons.shieldCheckBold,
      label: 'FSSAI\nVerified',
    ),
    _QualityItem(
      icon: PhosphorIcons.heartBold,
      label: 'Freshness\nGuaranteed',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 18.h),
      child: Row(
        children: <Widget>[
          for (final item in _items)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  PhosphorIcon(
                    item.icon,
                    size: 22.sp,
                    color: const Color(0xFF1A1414),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF666666),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _QualityItem {
  const _QualityItem({required this.icon, required this.label});

  final PhosphorIconData icon;
  final String label;
}
