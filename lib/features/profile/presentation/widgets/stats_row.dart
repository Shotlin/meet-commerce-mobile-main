import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/core/theme/app_text_styles.dart';
import 'package:bakaloo_flutter_app/features/profile/domain/entities/user_stats_entity.dart';
import 'package:bakaloo_flutter_app/core/utils/extensions/double_extensions.dart';

/// A single cohesive account-summary card holding the three key stats, each
/// separated by a hairline divider. Numbers use the brand violet accent.
class StatsRow extends StatelessWidget {
  const StatsRow({
    required this.stats,
    super.key,
  });

  final UserStatsEntity stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.orderCardBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0x0F000000),
            blurRadius: 10.r,
            offset: Offset(0, 3.h),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(vertical: 14.h),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _StatCell(
              icon: PhosphorIcons.bag,
              value: '${stats.totalOrders}',
              label: 'Delivered',
            ),
          ),
          _divider(),
          Expanded(
            child: _StatCell(
              icon: PhosphorIcons.wallet,
              value: _formatSpent(stats.totalSpent),
              label: 'Spent',
            ),
          ),
          _divider(),
          Expanded(
            child: _StatCell(
              icon: PhosphorIcons.sparkle,
              value: '${stats.loyaltyPoints}',
              label: 'Points',
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 34.h,
      color: AppColors.divider,
    );
  }

  String _formatSpent(double value) {
    if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}k';
    }
    return value.toInrCurrency;
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PhosphorIcon(icon, size: 16.sp, color: AppColors.textTertiary),
        Gap(6.h),
        Text(
          value,
          style: AppTextStyles.h1.copyWith(
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.orderViolet,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Gap(2.h),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            fontSize: 12.sp,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
