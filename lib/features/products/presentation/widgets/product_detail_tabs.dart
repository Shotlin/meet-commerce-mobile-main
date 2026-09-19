import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/products/domain/entities/product_entity.dart';

/// Description / Nutrition / Cooking Tips / Reviews tab strip. Each tab
/// only ever shows real product data — an empty tab says so plainly
/// rather than filling the gap with invented copy.
class ProductDetailTabs extends StatefulWidget {
  const ProductDetailTabs({required this.product, super.key});

  final ProductEntity product;

  @override
  State<ProductDetailTabs> createState() => _ProductDetailTabsState();
}

class _ProductDetailTabsState extends State<ProductDetailTabs> {
  int _index = 0;

  static const List<String> _tabs = <String>[
    'Description',
    'Nutrition',
    'Cooking Tips',
    'Reviews',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              for (int i = 0; i < _tabs.length; i++)
                Expanded(
                  child: _TabButton(
                    label: i == 3
                        ? 'Reviews (${widget.product.ratingCount})'
                        : _tabs[i],
                    selected: i == _index,
                    onTap: () => setState(() => _index = i),
                  ),
                ),
            ],
          ),
          const Divider(height: 1, color: Color(0xFFEDEDED)),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_index) {
      case 0:
        return _PlainText(
          (widget.product.description ?? '').trim().isNotEmpty
              ? widget.product.description!.trim()
              : 'No description available for this product yet.',
        );
      case 1:
        return _NutritionTable(info: widget.product.nutritionInfo);
      case 2:
        return _CookingTips(
          ingredients: widget.product.ingredients,
          storageInstructions: widget.product.storageInstructions,
        );
      case 3:
      default:
        return _ReviewsSummary(
          rating: widget.product.avgRating,
          count: widget.product.ratingCount,
        );
    }
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
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
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.brandRed : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.sp,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.brandRed : const Color(0xFF999999),
          ),
        ),
      ),
    );
  }
}

class _PlainText extends StatelessWidget {
  const _PlainText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13.sp,
        fontWeight: FontWeight.w400,
        color: const Color(0xFF444444),
        height: 1.5,
      ),
    );
  }
}

class _NutritionTable extends StatelessWidget {
  const _NutritionTable({required this.info});

  final Map<String, dynamic>? info;

  @override
  Widget build(BuildContext context) {
    final entries = (info ?? const <String, dynamic>{}).entries.toList();
    if (entries.isEmpty) {
      return const _PlainText(
          'Nutrition information not available for this product yet.');
    }

    return Column(
      children: <Widget>[
        for (int i = 0; i < entries.length; i++)
          Container(
            padding: EdgeInsets.symmetric(vertical: 9.h),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: i == entries.length - 1
                      ? Colors.transparent
                      : const Color(0xFFF0F0F0),
                ),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _titleCase(entries[i].key),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF666666),
                    ),
                  ),
                ),
                Text(
                  '${entries[i].value}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1414),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _titleCase(String key) {
    final spaced = key.replaceAllMapped(
      RegExp('([a-z0-9])([A-Z])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
    if (spaced.isEmpty) return spaced;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}

class _CookingTips extends StatelessWidget {
  const _CookingTips({this.ingredients, this.storageInstructions});

  final String? ingredients;
  final String? storageInstructions;

  @override
  Widget build(BuildContext context) {
    final ing = (ingredients ?? '').trim();
    final storage = (storageInstructions ?? '').trim();

    if (ing.isEmpty && storage.isEmpty) {
      return const _PlainText(
          'No cooking or storage tips available for this product yet.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (ing.isNotEmpty) ...<Widget>[
          _TipHeading('Ingredients'),
          SizedBox(height: 4.h),
          _PlainText(ing),
        ],
        if (ing.isNotEmpty && storage.isNotEmpty) SizedBox(height: 16.h),
        if (storage.isNotEmpty) ...<Widget>[
          _TipHeading('Storage & Handling'),
          SizedBox(height: 4.h),
          _PlainText(storage),
        ],
      ],
    );
  }
}

class _TipHeading extends StatelessWidget {
  const _TipHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13.sp,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1A1414),
      ),
    );
  }
}

class _ReviewsSummary extends StatelessWidget {
  const _ReviewsSummary({required this.rating, required this.count});

  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (rating <= 0 || count <= 0) {
      return const _PlainText(
          'No reviews yet — be the first to review this product.');
    }

    return Row(
      children: <Widget>[
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 32.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1414),
          ),
        ),
        SizedBox(width: 12.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: List<Widget>.generate(5, (i) {
                final filled = i < rating.round();
                return PhosphorIcon(
                  filled ? PhosphorIcons.starFill : PhosphorIcons.star,
                  size: 15.sp,
                  color: const Color(0xFFF5A623),
                );
              }),
            ),
            SizedBox(height: 2.h),
            Text(
              'Based on $count review${count == 1 ? '' : 's'}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF999999),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
