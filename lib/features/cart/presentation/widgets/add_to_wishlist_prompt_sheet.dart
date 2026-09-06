import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:bakaloo_flutter_app/features/wishlist/presentation/providers/wishlist_provider.dart';

/// Shown right after a customer removes something from their cart (single
/// item down to zero, swipe-to-delete, or a full "Clear cart") — a gentle
/// nudge to save the removed item(s) to the Wishlist instead of losing
/// track of them entirely. Purely additive: dismissing it just closes the
/// sheet, the removal itself has already completed by the time this shows.
Future<void> showAddToWishlistPrompt(
  BuildContext context, {
  required List<CartItemEntity> items,
}) {
  if (items.isEmpty) {
    return Future<void>.value();
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (_) => AddToWishlistPromptSheet(items: items),
  );
}

class AddToWishlistPromptSheet extends ConsumerStatefulWidget {
  const AddToWishlistPromptSheet({required this.items, super.key});

  final List<CartItemEntity> items;

  @override
  ConsumerState<AddToWishlistPromptSheet> createState() =>
      _AddToWishlistPromptSheetState();
}

class _AddToWishlistPromptSheetState
    extends ConsumerState<AddToWishlistPromptSheet> {
  bool _isSaving = false;

  Future<void> _addAll() async {
    setState(() => _isSaving = true);

    final notifier = ref.read(wishlistProvider.notifier);
    String? failureMessage;
    for (final item in widget.items) {
      final result = await notifier.addToWishlistById(item.productId);
      if (!result.isSuccess) {
        failureMessage = result.failure!.message;
        break;
      }
    }

    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            failureMessage ??
                (widget.items.length == 1
                    ? 'Saved to your Wishlist'
                    : 'Saved ${widget.items.length} items to your Wishlist'),
          ),
          backgroundColor: failureMessage == null
              ? AppColors.orderViolet
              : AppColors.errorRed,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final isMultiple = items.length > 1;

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 20.h),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: const BoxDecoration(
                    color: AppColors.orderVioletSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: AppColors.orderViolet,
                    size: 24.sp,
                  ),
                ),
                Gap(14.w),
                Expanded(child: _ItemPreview(items: items)),
              ],
            ),
            Gap(20.h),
            Text(
              isMultiple ? 'Save these for later?' : 'Save this for later?',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
                fontFamily: 'Inter',
              ),
            ),
            Gap(6.h),
            Text(
              isMultiple
                  ? "We've removed ${items.length} items from your cart. "
                      "Add them to your Wishlist so you don't lose track "
                      'of them.'
                  : 'Add "${items.first.name}" to your Wishlist so you '
                      "don't lose track of it.",
              style: TextStyle(
                fontSize: 13.5.sp,
                color: const Color(0xFF666666),
                fontFamily: 'Inter',
                height: 1.4,
              ),
            ),
            Gap(22.h),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF555555),
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      minimumSize: Size(0, 48.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: const Text('Not now'),
                  ),
                ),
                Gap(12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _addAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orderViolet,
                      foregroundColor: Colors.white,
                      minimumSize: Size(0, 48.h),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Add to Wishlist'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Single item: thumbnail + name + price, matching the cart row's own
/// layout. Multiple items: a compact row of small thumbnails so the
/// customer can still recognise what's being offered without the sheet
/// growing tall.
class _ItemPreview extends StatelessWidget {
  const _ItemPreview({required this.items});

  final List<CartItemEntity> items;

  @override
  Widget build(BuildContext context) {
    if (items.length == 1) {
      final item = items.first;
      return Row(
        children: <Widget>[
          _Thumb(url: item.thumbnailUrl, size: 52.w),
          Gap(10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF222222),
                    fontFamily: 'Inter',
                  ),
                ),
                Gap(3.h),
                Text(
                  '₹${item.effectivePrice.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.orderViolet,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    const maxThumbs = 4;
    final shown = items.take(maxThumbs).toList(growable: false);
    final remaining = items.length - shown.length;

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: <Widget>[
          for (final item in shown) _Thumb(url: item.thumbnailUrl, size: 44.w),
          if (remaining > 0)
            Container(
              width: 44.w,
              height: 44.w,
              decoration: const BoxDecoration(
                color: AppColors.orderVioletSurface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '+$remaining',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.orderViolet,
                  fontFamily: 'Inter',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10.r),
      child: SizedBox(
        width: size,
        height: size,
        child: (url != null && url!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                memCacheWidth: 128,
                memCacheHeight: 128,
                fadeInDuration: const Duration(milliseconds: 150),
                errorWidget: (context, url, error) => _thumbFallback(),
              )
            : _thumbFallback(),
      ),
    );
  }

  Widget _thumbFallback() {
    return Container(
      color: const Color(0xFFF4F4F4),
      alignment: Alignment.center,
      child: Icon(
        Icons.shopping_basket_outlined,
        size: size * 0.4,
        color: const Color(0xFFCCCCCC),
      ),
    );
  }
}
