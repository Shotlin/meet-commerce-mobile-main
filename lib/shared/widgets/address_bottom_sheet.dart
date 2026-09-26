import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/core/theme/app_colors.dart';
import 'package:bakaloo_flutter_app/features/addresses/presentation/providers/address_provider.dart';
import 'package:bakaloo_flutter_app/features/products/presentation/widgets/show_product_options.dart';
import 'package:bakaloo_flutter_app/routing/route_names.dart';

/// Opens the delivery address bottom sheet.
///
/// Shows the current selected/default address and a "Manage Addresses" button.
/// Automatically hides the floating cart pill while the sheet is open.
void showAddressSheet(BuildContext context) {
  addressSheetVisible.value = true;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const AddressBottomSheet(),
  ).whenComplete(() {
    addressSheetVisible.value = false;
  });
}

/// Bottom sheet that displays the current delivery address and a
/// "Manage Addresses" navigation button.
class AddressBottomSheet extends ConsumerWidget {
  const AddressBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Was previously tinted off `selectedStoreProvider` — the leftover
    // multi-store demo shell (Zepto/50% OFF Zone/Super Mall/Cafe, see
    // core/models/store_model.dart), whose default/first entry ("Zepto")
    // happens to be light blue. A customer's delivery address has nothing
    // to do with which of those demo store tabs is selected, so this sheet
    // always renders in the real FreshCuts brand red now, regardless.
    const storeColor = AppColors.brandRed;
    const storeBgColor = AppColors.brandRedSurface;
    const storeBorderColor = AppColors.brandRedBorder;

    // Resolve the currently selected / default address for display.
    final addresses = ref.watch(addressProvider).asData?.value;
    final currentAddress = addresses != null && addresses.isNotEmpty
        ? addresses.firstWhere(
            (a) => a.isDefault,
            orElse: () => addresses.first,
          )
        : null;

    // Build a readable one-line address summary.
    String addressSummary = 'No address set';
    if (currentAddress != null) {
      final parts = <String>[
        if (currentAddress.addressLine1.trim().isNotEmpty)
          currentAddress.addressLine1.trim(),
        if (currentAddress.city.trim().isNotEmpty) currentAddress.city.trim(),
        if (currentAddress.pincode.trim().isNotEmpty)
          currentAddress.pincode.trim(),
      ];
      if (parts.isNotEmpty) addressSummary = parts.join(', ');
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: storeBgColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: storeColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Delivery Address',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ── Current address display ──────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: storeBgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: storeBorderColor, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: storeColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: currentAddress != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (currentAddress.label.trim().isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: storeBorderColor),
                                ),
                                child: Text(
                                  currentAddress.label.trim(),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: storeColor,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            Text(
                              addressSummary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                                height: 1.35,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Add your delivery address',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Manage Addresses button ──────────────────────────────────
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              context.go(RouteNames.addresses);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: storeColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x33D02428),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.edit_location_alt_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Manage Addresses',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
