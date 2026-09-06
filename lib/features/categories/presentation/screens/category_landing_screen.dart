import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/routing/app_router.dart';
import 'package:bakaloo_flutter_app/features/categories/domain/entities/category_entity.dart';
import 'package:bakaloo_flutter_app/features/categories/presentation/providers/category_provider.dart';
import 'package:bakaloo_flutter_app/features/home/domain/entities/banner_entity.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/providers/banner_provider.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';
import 'package:bakaloo_flutter_app/shared/utils/address_utils.dart';
import 'package:bakaloo_flutter_app/shared/widgets/address_bottom_sheet.dart';
import 'package:bakaloo_flutter_app/shared/widgets/error_state.dart';
import 'package:bakaloo_flutter_app/shared/widgets/skeleton_loader.dart';

const Color _brandRed = AppColors.brandRed;
const String _logoAsset = 'assets/icon/brand_logo.png';

/// Category-tab landing page — shown first when the bottom nav "Categories"
/// tab is pressed. Tapping any category tile pushes into the existing
/// rail+grid [CategoriesScreen] (unchanged) pre-selected to that category.
class CategoryLandingScreen extends ConsumerWidget {
  const CategoryLandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryCollectionProvider);
    final topBannersAsync = ref.watch(categoryPageBannersProvider);
    final footerBannersAsync = ref.watch(categoryFooterBannersProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: <Widget>[
            const SliverToBoxAdapter(child: _TopBar()),
            const SliverToBoxAdapter(child: _HeadlineRow()),
            SliverToBoxAdapter(
              child: _BannerCarousel(
                bannersAsync: topBannersAsync,
                height: 150.h,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 4.h),
              sliver: categoriesAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: _CategoryGridSkeleton(),
                ),
                error: (error, stackTrace) => SliverToBoxAdapter(
                  child: ErrorState(
                    message: 'Categories could not be loaded.',
                    onRetry: () => ref.invalidate(categoryCollectionProvider),
                  ),
                ),
                data: (categories) => _CategoryGrid(categories: categories),
              ),
            ),
            SliverToBoxAdapter(
              child: _BannerCarousel(
                bannersAsync: footerBannersAsync,
                height: 140.h,
              ),
            ),
            SliverToBoxAdapter(child: Gap(24.h)),
          ],
        ),
      ),
    );
  }
}

// ── Top bar: logo + location ────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final addresses =
        currentUser == null ? null : ref.watch(addressProvider).asData?.value;
    final addressLabel = resolveAddressLabel(
      isLoggedIn: currentUser != null,
      addresses: addresses,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 6.h),
      child: Row(
        children: <Widget>[
          Image.asset(
            _logoAsset,
            height: 28.h,
            cacheHeight: 112,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => showAddressSheet(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              constraints: BoxConstraints(maxWidth: 190.w),
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.location_on_outlined,
                      size: 15.sp, color: _brandRed),
                  Gap(4.w),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Deliver to',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9.sp,
                            color: AppColors.textTertiary,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          addressLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16.sp, color: AppColors.textTertiary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Headline + search ───────────────────────────────────────────────────

class _HeadlineRow extends StatelessWidget {
  const _HeadlineRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Categories',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                Gap(3.h),
                Text(
                  'Fresh meats, seafood & more. Delivered fresh to your doorstep.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Gap(10.w),
          Semantics(
            button: true,
            label: 'Search',
            child: InkWell(
              onTap: () => context.push(RouteNames.search),
              customBorder: const CircleBorder(),
              child: Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Center(
                  child: PhosphorIcon(
                    PhosphorIcons.magnifyingGlassBold,
                    size: 19.sp,
                    color: _brandRed,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Banner carousel — reused for both the top carousel
// (banner_type='category') and the bottom combo carousel
// (banner_type='category_footer'). Every card is a pure, full-bleed image
// (see _CategoryBannerCard) — no app-rendered text or button, since the
// admin-uploaded artwork already carries that.

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.bannersAsync, required this.height});

  final AsyncValue<List<BannerEntity>> bannersAsync;
  final double height;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final PageController _pageController = PageController();
  Timer? _autoPlayTimer;
  int _page = 0;
  int _lastLength = -1;

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _syncAutoPlay(int length) {
    if (length == _lastLength) return;
    _lastLength = length;
    _autoPlayTimer?.cancel();
    if (length <= 1) return;
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_page + 1) % length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.bannersAsync.when(
      loading: () => Padding(
        padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 0),
        child: SkeletonLoader(height: widget.height, radius: 16),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (banners) {
        if (banners.isEmpty) return const SizedBox.shrink();
        _syncAutoPlay(banners.length);

        return Padding(
          padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 0),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: widget.height,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: banners.length,
                  onPageChanged: (index) => setState(() => _page = index),
                  itemBuilder: (context, index) =>
                      _CategoryBannerCard(banner: banners[index]),
                ),
              ),
              if (banners.length > 1) ...<Widget>[
                Gap(8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(banners.length, (index) {
                    final active = index == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.symmetric(horizontal: 3.w),
                      width: active ? 16.w : 6.w,
                      height: 6.w,
                      decoration: BoxDecoration(
                        color: active ? _brandRed : AppColors.borderLight,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Pure-image banner — the artwork (title, subtitle, CTA button) is baked
/// into the admin-uploaded image itself, so this renders no overlay text or
/// button of its own; the whole card is one tap target to the linked page.
class _CategoryBannerCard extends StatelessWidget {
  const _CategoryBannerCard({required this.banner});

  final BannerEntity banner;

  @override
  Widget build(BuildContext context) {
    final optimized = ApiConstants.optimizedMedia(
      banner.imageUrl,
      profile: CustomerImageProfile.banner,
    );
    final routePath = _resolveBannerRoute(banner);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16.r),
      child: GestureDetector(
        onTap: routePath == null ? null : () => context.push(routePath),
        // BoxFit.cover — fills this box edge-to-edge with no white space.
        // The dashboard's banner upload now recommends 1200×500px (~2.4:1,
        // matching this box's own aspect ratio) so following that guidance
        // means no meaningful cropping either.
        child: CachedNetworkImage(
          imageUrl: optimized.url ?? banner.imageUrl,
          memCacheWidth: optimized.memCacheWidth,
          memCacheHeight: optimized.memCacheHeight,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder: (context, url) =>
              const ColoredBox(color: Color(0xFFF5F5F5)),
          errorWidget: (context, url, error) =>
              const ColoredBox(color: Color(0xFFF5F5F5)),
        ),
      ),
    );
  }
}

/// 'category' linkType → the dedicated rail+grid category screen (the
/// same destination category-grid tiles use); 'product' → product detail;
/// anything else → no tap target.
String? _resolveBannerRoute(BannerEntity banner) {
  final linkValue = banner.linkValue?.trim();
  if (linkValue == null || linkValue.isEmpty) return null;

  final type = banner.linkType.toLowerCase();
  if (type.contains('product')) {
    return '/product/$linkValue';
  }
  if (type.contains('category')) {
    return Uri(
      path: RouteNames.categoriesBrowse,
      queryParameters: <String, String>{'categoryId': linkValue},
    ).toString();
  }
  return null;
}

// ── Category icon grid ──────────────────────────────────────────────────

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories});

  final List<CategoryEntity> categories;

  @override
  Widget build(BuildContext context) {
    final visible = categories
        .where((c) => c.isActive && !c.isBundle && c.isParent)
        .toList(growable: false)
      ..sort((a, b) {
        final sortOrder = a.sortOrder.compareTo(b.sortOrder);
        if (sortOrder != 0) return sortOrder;
        return a.name.compareTo(b.name);
      });

    if (visible.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        const int crossAxisCount = 3;
        final double spacing = 10.w;
        final double columnWidth =
            (constraints.crossAxisExtent - spacing * (crossAxisCount - 1)) /
                crossAxisCount;
        // Square image + the name/count/chevron info row beneath it.
        final double infoRowHeight = 60.h;

        return SliverGrid.builder(
          itemCount: visible.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: 12.h,
            mainAxisExtent: columnWidth + infoRowHeight,
          ),
          itemBuilder: (context, index) =>
              _CategoryGridTile(category: visible[index]),
        );
      },
    );
  }
}

/// Card tile: square category image on top, name + item count + a chevron
/// in a white footer strip beneath it — tapping anywhere on the card opens
/// the existing dedicated rail+grid category screen pre-selected to it.
class _CategoryGridTile extends StatelessWidget {
  const _CategoryGridTile({required this.category});

  final CategoryEntity category;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        category.imageUrl != null && category.imageUrl!.trim().isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14.r),
      clipBehavior: Clip.antiAlias,
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: InkWell(
        onTap: () => context.push(
          Uri(
            path: RouteNames.categoriesBrowse,
            queryParameters: <String, String>{'categoryId': category.id},
          ).toString(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 1,
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: category.imageUrl!,
                      memCacheWidth: 260,
                      memCacheHeight: 260,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const SkeletonLoader(height: 100, radius: 0),
                      errorWidget: (context, url, error) =>
                          _GridMonogram(name: category.name),
                    )
                  : _GridMonogram(name: category.name),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 7.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          '${category.productCount} items',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9.5.sp,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textTertiary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 15.sp, color: AppColors.textTertiary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridMonogram extends StatelessWidget {
  const _GridMonogram({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return ColoredBox(
      color: AppColors.bgInput,
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 26.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _CategoryGridSkeleton extends StatelessWidget {
  const _CategoryGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const int crossAxisCount = 3;
        final double spacing = 10.w;
        final double columnWidth =
            (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                crossAxisCount;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: 12.h,
            mainAxisExtent: columnWidth + 60.h,
          ),
          itemBuilder: (_, __) => SkeletonLoader(
            height: columnWidth + 60.h,
            radius: 14,
          ),
        );
      },
    );
  }
}
