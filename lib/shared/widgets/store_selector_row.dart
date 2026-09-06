import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/core/models/store_model.dart';
import 'package:bakaloo_flutter_app/core/providers/store_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/widgets/active_chip_clipper.dart';

class StoreSelectorRow extends ConsumerWidget {
  const StoreSelectorRow({
    super.key,
    this.selectorTheme,
  });

  final StoreSelectorTheme? selectorTheme;

  static const List<Map<String, String>> _chips = <Map<String, String>>[
    <String, String>{
      'id': 'zepto',
      'path': 'assets/images/Bakaloo.png',
      'route': '/home',
    },
    <String, String>{
      'id': 'off_zone',
      'path': 'assets/images/50%_OFF_zone.png',
      'route': RouteNames.offZone,
    },
    <String, String>{
      'id': 'super_mall',
      'path': 'assets/images/Super_mall.png',
      'route': RouteNames.superMall,
    },
    <String, String>{
      'id': 'cafe',
      'path': 'assets/images/Cafe.png',
      'route': RouteNames.cafe,
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultSelectorTheme = StoreSelectorTheme.defaults();
    final headerBg =
        selectorTheme?.backgroundColor ?? defaultSelectorTheme.backgroundColor;
    final activeChipColor =
        selectorTheme?.activeChipColor ?? defaultSelectorTheme.activeChipColor;
    final selectedId = ref.watch(selectedStoreProvider).id;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final chipWidth = (screenWidth - 48) / 4;

    return Container(
      color: headerBg,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _chips.map((chip) {
          final isActive = chip['id'] == selectedId;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              if (!isActive) {
                final store = appStores.firstWhere((s) => s.id == chip['id']);
                ref.read(selectedStoreProvider.notifier).select(store);
                ref.read(selectedCategoryIdProvider.notifier).select('');
              }
              context.go(chip['route']!);
            },
            child: isActive
                ? _ActiveChip(
                    width: chipWidth,
                    imagePath: chip['path']!,
                    activeChipColor: activeChipColor,
                  )
                : _InactiveChip(width: chipWidth, imagePath: chip['path']!),
          );
        }).toList(),
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip({
    required this.width,
    required this.imagePath,
    required this.activeChipColor,
  });

  final double width;
  final String imagePath;
  final Color activeChipColor;

  static const double _chipHeight = 60;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: _chipHeight,
      child: ClipPath(
        clipper: const ActiveChipClipper(),
        child: Container(
          width: width,
          height: _chipHeight,
          color: activeChipColor,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _InactiveChip extends StatelessWidget {
  const _InactiveChip({required this.width, required this.imagePath});

  final double width;
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 55,
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(7),
      child: Image.asset(
        imagePath,
        fit: BoxFit.contain,
      ),
    );
  }
}
