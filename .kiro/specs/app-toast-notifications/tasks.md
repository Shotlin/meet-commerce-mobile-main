# Implementation Plan

- [x] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Bottom Snackbar & Silent Max-Qty Bugs
  - **CRITICAL**: This test MUST FAIL on unfixed code — failure confirms the bugs exist
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior — it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples demonstrating both C₁ (bottom snackbar renderer) and C₂ (silent max-qty rejection)
  - **Scoped PBT Approach**: For deterministic bugs, scope to concrete failing cases for reproducibility
  - Create `test/widget/notifications/app_toast_bug_condition_test.dart`
  - **C₁ test**: Pump a widget that calls `showCartSnackBar(context, 'error message')`, then assert: no `SnackBar` widget in tree AND an overlay card exists at the top viewport — fails on unfixed code because `SnackBar` IS found and no overlay card exists
  - **C₁ test variant**: Pump `ProfileScreen` stub, simulate "Payment settings" tap that triggers `ScaffoldMessenger.showSnackBar(SnackBar(content: Text('Coming soon')))`, assert no `SnackBar` in tree and info-styled overlay card present — fails on unfixed code
  - **C₂ test**: Pump a widget wrapping `_QuantityStepper` with `quantity = 5` and `maxOrderQty = 5`, tap the "+" icon, assert a warning overlay card is displayed containing "Maximum 5 items" — fails on unfixed code because no feedback appears at all
  - **C₂ edge case**: Same test with `maxOrderQty = null` and `quantity = 50` — fails on unfixed code
  - Run tests on UNFIXED code: `flutter test test/widget/notifications/app_toast_bug_condition_test.dart`
  - **EXPECTED OUTCOME**: Tests FAIL — this is correct, it proves both bugs exist
  - Document counterexamples found (e.g., "C₁: SnackBar widget found in tree at bottom, no overlay card; C₂: no widget response at all to tap")
  - Mark task complete when tests are written, run, and failure is documented
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Non-Notification Behavior Unchanged
  - **IMPORTANT**: Follow observation-first methodology — observe unfixed code behavior for non-buggy inputs, then encode as tests
  - **Non-bug condition scope**: inputs where `isBugCondition_BottomSnackBar(X) = false` AND `isBugCondition_SilentMaxQty(X) = false`
  - Create `test/widget/notifications/app_toast_preservation_test.dart`
  - **Stepper in-range test (parameterized over quantity values)**: For `quantity` in `[1, 2, 3, 4]` with `maxOrderQty = 5`, observe that tapping "+" calls `cartProvider.updateItem(id, quantity + 1)` exactly once and shows NO toast — write loop over these values to simulate PBT
  - **Cart add preservation test**: A successful `cartProvider.addItem()` must update cart item count and emit NO notification overlay (no `SnackBar`, no `AppToast` card) for the success path
  - **`_mapCartErrorMessage` unit test**: Verify that the function continues to map "refresh token" → session-expired text, "allocation" → address-required text, "uuid" → generic error text, and unknown strings → generic error text — zero behavior change expected
  - **No-SnackBar invariant**: After the fix no widget test should ever find a `SnackBar` widget in the tree — write a helper that asserts `find.byType(SnackBar)` is empty after any action
  - Observe and record outputs on UNFIXED code before encoding assertions
  - Run tests on UNFIXED code: `flutter test test/widget/notifications/app_toast_preservation_test.dart`
  - **EXPECTED OUTCOME**: Tests PASS — this confirms the baseline behavior to preserve
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_

- [ ] 3. Fix — replace bottom snackbar layer with AppToast and wire up silent max-qty feedback

  - [x] 3.1 Create `lib/core/utils/app_toast.dart`
    - Define `enum ToastType { error, warning, success, info }`
    - Create `AppToast` class with `static OverlayEntry? _currentEntry` field
    - Implement `static String _inferType(String message)` using the keyword lists from the design: session/jwt/refresh-token/unauthorized/expired → `error`; maximum/max/unavailable/set your delivery/address required → `warning`; successfully/cancelled/deleted/added/saved/updated/removed → `success`; coming soon → `info`; default → `error`
    - Implement `static void show(BuildContext context, String message, {ToastType? type, Duration duration = const Duration(milliseconds: 3500)})` using `Overlay.of(context)` — NOT `ScaffoldMessenger`
    - Remove any existing `_currentEntry` before inserting a new one (no card stacking)
    - Create `_ToastOverlay` as a `StatefulWidget` that holds its own `AnimationController` with `TickerProviderStateMixin`, duration 300 ms, and drives both `SlideTransition` (from `Offset(0, -1)` to `Offset.zero`, `Curves.easeOutCubic`) and `FadeTransition`
    - Reverse animation then `entry.remove()` on tap and on timer completion
    - Use `SafeArea` + `Padding(top: 12.h, horizontal: 16.w)` for top positioning
    - Create `_ToastCard` `StatelessWidget` with: `BoxDecoration` (borderRadius 14.r, left `BorderSide` 4.w accent colour, boxShadow blurRadius 12 offset (0,4) color 0x1A000000, tinted background `accentColour.withOpacity(0.08)`), `PhosphorIcon` (20.sp), `Gap(10.w)`, `Expanded Text` using `AppTextStyles.bodyMedium` with `fontWeight: FontWeight.w600`
    - Use phosphor_flutter icons: `PhosphorIcons.xCircle()` for error, `PhosphorIcons.warning()` for warning, `PhosphorIcons.checkCircle()` for success, `PhosphorIcons.info()` for info
    - Import `AppColors` from `lib/core/theme/app_colors.dart` and `AppTextStyles` from `lib/core/theme/app_text_styles.dart`
    - _Bug_Condition: isBugCondition_BottomSnackBar(X): X.renderedVia = ScaffoldMessenger OR showCartSnackBar_
    - _Expected_Behavior: result.positionedAt = TOP, result.renderedVia = Overlay, result.hasIcon = true, result.autoDismissAfter ∈ [3s, 4s]_
    - _Preservation: AppToast is call-site decoration only; cart state mutations in CartNotifier are untouched_
    - _Requirements: 2.1, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 2.11, 2.12, 2.13_

  - [x] 3.2 Update `showCartSnackBar` in `lib/features/cart/presentation/providers/cart_provider.dart`
    - Add import: `import 'package:bakaloo_flutter_app/core/utils/app_toast.dart';`
    - Replace the body of `showCartSnackBar` — keep the `_mapCartErrorMessage(message)` call, delegate result to `AppToast.show(context, displayMessage)` instead of `ScaffoldMessenger`
    - Remove the `isError` color-selection logic and `SnackBar(...)` construction — type is now auto-detected by `AppToast._inferType()`
    - Keep `_mapCartErrorMessage` function body completely unchanged (preservation requirement 3.5)
    - The 5 existing `showCartSnackBar(...)` calls in `cart_screen.dart` require no edits after this change
    - _Bug_Condition: isBugCondition_BottomSnackBar(X): X.renderedVia = showCartSnackBar_
    - _Requirements: 2.1, 2.3, 3.5_

  - [x] 3.3 Fix silent max-qty guard in `lib/features/products/presentation/widgets/product_option_bottom_sheet.dart`
    - Add import for `AppToast` and `ToastType`
    - In `_QuantityStepper`'s "+" `onTap` handler, before `if (quantity >= (option.maxOrderQty ?? 50)) return;` — add `AppToast.show(context, '⚠️ Maximum ${option.maxOrderQty ?? 50} items allowed per order', type: ToastType.warning);` then `return;`
    - Replace the existing `showCartSnackBar(context, result.failure!.message)` calls in the ADD button and stepper decrement error path with `AppToast.show(context, result.failure!.message)`
    - All other stepper logic (decrement, in-range increment, quantity state) must remain byte-for-byte identical
    - _Bug_Condition: isBugCondition_SilentMaxQty(X): X.direction = increment AND X.currentQuantity >= (X.maxOrderQty ?? 50)_
    - _Expected_Behavior: result.toastShown = true, result.toastType = warning, result.toastMessage CONTAINS "Maximum" AND string(maxOrderQty ?? 50)_
    - _Requirements: 2.2_

  - [x] 3.4 Replace `ScaffoldMessenger` calls in `lib/features/orders/presentation/screens/orders_screen.dart`
    - Add import for `AppToast` and `ToastType`
    - Replace `_showSnackBar(failure.message)` in the cancel-order failure branch with `AppToast.show(context, failure.message)`
    - Replace `_showSnackBar('Order cancelled successfully')` with `AppToast.show(context, '✅ Order cancelled successfully', type: ToastType.success)`
    - Replace `_showSnackBar(failure.message)` in the reorder failure branch with `AppToast.show(context, failure.message)`
    - Replace the `ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text('Items added to cart$warnings')))` block with `AppToast.show(context, 'Items added to cart$warnings', type: ToastType.success)`
    - Remove or inline `_showSnackBar` helper method if it becomes unused
    - _Requirements: 2.1, 2.3, 2.6_

  - [x] 3.5 Replace `ScaffoldMessenger` calls in `lib/features/orders/presentation/screens/order_detail_screen.dart`
    - Add import for `AppToast` and `ToastType`
    - Replace all 4 `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)))` calls with `AppToast.show(context, failure.message)`
    - Replace `ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order cancelled successfully')))` with `AppToast.show(context, '✅ Order cancelled successfully', type: ToastType.success)`
    - Replace `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Items added to cart$warnings')))` with `AppToast.show(context, 'Items added to cart$warnings', type: ToastType.success)`
    - _Requirements: 2.1, 2.3, 2.6_

  - [x] 3.6 Replace `ScaffoldMessenger` calls in `lib/features/profile/presentation/screens/profile_screen.dart`
    - Add import for `AppToast` and `ToastType`
    - Replace the state-listener `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)))` (profile error) with `AppToast.show(context, message)`
    - Replace "Payment settings" `onTap` `showSnackBar(SnackBar(content: Text('Coming soon')))` with `AppToast.show(context, '🚀 Coming soon!', type: ToastType.info)`
    - Replace "Privacy" `onTap` `showSnackBar(SnackBar(content: Text('Coming soon')))` with `AppToast.show(context, '🚀 Coming soon!', type: ToastType.info)`
    - Replace the two `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.failure!.message)))` calls (photo upload / other action failures) with `AppToast.show(context, result.failure!.message)`
    - _Requirements: 2.1, 2.3, 2.7_

  - [x] 3.7 Replace `ScaffoldMessenger` calls in `lib/features/addresses/presentation/screens/address_list_screen.dart`
    - Add import for `AppToast` and `ToastType`
    - Replace the failure-path `messenger..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(result.failure?.message ?? 'Unable to delete address.')))` with `AppToast.show(context, result.failure?.message ?? 'Unable to delete address.')`
    - Replace the success-path `messenger..hideCurrentSnackBar()..showSnackBar(const SnackBar(content: Text('Address deleted.')))` with `AppToast.show(context, '✅ Address deleted.', type: ToastType.success)`
    - _Requirements: 2.1, 2.3, 2.6_

  - [x] 3.8 Replace `ScaffoldMessenger` calls in `lib/features/notifications/presentation/screens/notifications_screen.dart`
    - Add import for `AppToast`
    - Replace all 3 `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.failure!.message)))` calls with `AppToast.show(context, result.failure!.message)`
    - _Requirements: 2.1, 2.3_

  - [x] 3.9 Replace `_showSnackBar` calls in `lib/features/checkout/presentation/screens/checkout_screen.dart`
    - Add import for `AppToast` and `ToastType`
    - Replace `_showSnackBar(msg, isError: true)` in error-state listener with `AppToast.show(context, msg)`
    - Replace the direct `ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(...)` block in the second listener with `AppToast.show(context, ...)`
    - Replace `_showSnackBar('Please choose a delivery address first.')` with `AppToast.show(context, '📍 Please choose a delivery address first.', type: ToastType.warning)`
    - Replace `_showSnackBar(result.errorMessage!, isError: true)` with `AppToast.show(context, result.errorMessage!)`
    - Remove or inline `_showSnackBar` helper if it becomes unused
    - _Requirements: 2.1, 2.3, 2.10_

  - [x] 3.10 Replace `_showSnackBar` calls in `lib/features/addresses/presentation/screens/add_edit_address_screen.dart`
    - Add import for `AppToast` and `ToastType`
    - Replace `_showSnackBar('Location permission is required to detect your location.')` with `AppToast.show(context, '📍 Location permission is required to detect your location.', type: ToastType.warning)`
    - Replace `_showSnackBar('Turn on location services and try again.')` with `AppToast.show(context, '📍 Turn on location services and try again.', type: ToastType.warning)`
    - Replace `_showSnackBar(error...)` in exception handler with `AppToast.show(context, error...)`
    - Replace `_showSnackBar('Receiver details are already filled.')` with `AppToast.show(context, 'Receiver details are already filled.', type: ToastType.info)`
    - Replace `_showSnackBar('Add receiver details manually.')` with `AppToast.show(context, 'Add receiver details manually.', type: ToastType.info)`
    - Remove or inline `_showSnackBar` helper if it becomes unused
    - _Requirements: 2.1, 2.3_

  - [x] 3.11 Replace `ScaffoldMessenger` calls in `lib/features/reviews/presentation/screens/write_review_screen.dart`
    - Add import for `AppToast` and `ToastType`
    - Replace `ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a rating')))` with `AppToast.show(context, '⚠️ Please select a rating', type: ToastType.warning)`
    - Replace `ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review is not available for this product yet.')))` with `AppToast.show(context, '⚠️ Review is not available for this product yet.', type: ToastType.warning)`
    - Replace the remaining `ScaffoldMessenger.of(context).showSnackBar(...)` failure calls with `AppToast.show(context, ...)`
    - _Requirements: 2.1, 2.3, 2.5_

  - [x] 3.12 Replace `ScaffoldMessenger` calls in `lib/features/wallet/presentation/screens/topup_screen.dart`
    - Add import for `AppToast` and `ToastType`
    - Replace the Razorpay response handler `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message ?? '...')))` with `AppToast.show(context, message ?? 'Payment failed. Please try again.')`
    - Replace `ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')))` with `AppToast.show(context, '⚠️ Enter a valid amount', type: ToastType.warning)`
    - Replace `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.failure!.message)))` with `AppToast.show(context, result.failure!.message)`
    - _Requirements: 2.1, 2.3_

  - [ ] 3.13 Build release APK and install on device
    - Run from workspace root: `flutter build apk --release`
    - Install the built APK at `build/app/outputs/flutter-apk/app-release.apk` using mobile MCP
    - Launch the app and visually verify: toast appears at the top of the screen, slides in smoothly, has correct icon and colour, auto-dismisses, and does NOT overlap the bottom navigation bar
    - Verify: tap "Payment settings" in profile → info toast at top with `🚀 Coming soon!`
    - Verify: add item already at max qty → warning toast at top with "Maximum N items"
    - _Requirements: 2.1, 2.2, 2.3, 2.11, 2.12_

  - [ ] 3.14 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Bottom Snackbar Replaced, Max-Qty Feedback Added
    - **IMPORTANT**: Re-run the SAME tests from task 1 — do NOT write new tests
    - Run: `flutter test test/widget/notifications/app_toast_bug_condition_test.dart`
    - **EXPECTED OUTCOME**: Tests PASS — confirms C₁ (overlay card at top, no SnackBar) and C₂ (warning toast on max-qty tap) are both fixed
    - _Requirements: 2.1, 2.2, 2.3, 2.11, 2.12_

  - [ ] 3.15 Verify preservation tests still pass
    - **Property 2: Preservation** - Non-Notification Behavior Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 — do NOT write new tests
    - Run: `flutter test test/widget/notifications/app_toast_preservation_test.dart`
    - **EXPECTED OUTCOME**: Tests PASS — confirms no regressions in cart state, stepper in-range increments, `_mapCartErrorMessage` mapping, and routing
    - Confirm all tests still pass after fix (no regressions)

- [ ] 4. Checkpoint — Ensure all tests pass
  - Run full test suite: `flutter test`
  - Confirm no `SnackBar` widget appears anywhere in the widget tree during tests
  - Confirm the release APK is built and visual verification from 3.13 is complete
  - Ask the user if any questions arise before closing the spec
