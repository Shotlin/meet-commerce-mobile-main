import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bakaloo_flutter_app/core/providers/store_provider.dart';
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
    final storeColor = ref.watch(
      selectedStoreProvider.select((store) => store.chipActiveColor),
    );
    final storeBgColor = ref.watch(
      selectedStoreProvider.select((store) => store.backgroundColor),
    );

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
          const SizedBox(height: 16),
          const Text(
            'Delivery Address',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          // ── Current address display ──────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: storeBgColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: storeColor.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.location_on_rounded,
                  color: storeColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: currentAddress != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (currentAddress.label.trim().isNotEmpty)
                              Text(
                                currentAddress.label.trim(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: storeColor,
                                  height: 1.2,
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
                color: storeBgColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Manage Addresses',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: storeColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
