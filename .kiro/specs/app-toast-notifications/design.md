# App Toast Notifications Bugfix Design

## Overview

The Bakaloo Flutter app surfaces all user-facing notifications — cart errors, session
warnings, success confirmations, info messages, and validation results — via Flutter's
default `SnackBar` / `ScaffoldMessenger` stack. These appear at the **bottom** of the
screen, partially behind the bottom navigation bar, carry no icons or emoji, expose raw
backend error strings after only partial sanitisation, and make no visual distinction
between error, warning, success, and info severities.

A second, related bug exists in the quantity stepper inside `ProductOptionBottomSheet`:
when the user taps "+" and the item is already at its maximum allowed quantity
(`quantity >= option.maxOrderQty ?? 50`), the handler silently returns — the user has
no idea why their tap did nothing.

This fix replaces the entire notification presentation layer with a new `AppToast`
utility (`lib/core/utils/app_toast.dart`) that inserts a premium card via Flutter's
`Overlay` API at the **top** of the viewport, independent of the `Scaffold`/
`ScaffoldMessenger` hierarchy. It also wires up the silent max-quantity guard to emit a
warning toast before returning.

---

## Glossary

- **Bug_Condition (C)**: The set of runtime events that trigger the defective behaviour —
  specifically (C₁) any notification rendered via `ScaffoldMessenger`/`showCartSnackBar`,
  and (C₂) a "+" tap on the quantity stepper when `quantity >= maxOrderQty`.
- **Property (P)**: The desired outcome for inputs satisfying C — a top-positioned
  `AppToast` with the correct type, icon, colour, and auto-dismiss.
- **Preservation**: All non-notification behaviour (cart state mutations, routing, UI
  rendering, quantity stepper for in-range quantities) that must remain byte-for-byte
  identical before and after the fix.
- **AppToast**: The new `Overlay`-based notification widget defined in
  `lib/core/utils/app_toast.dart`.
- **ToastType**: An enum with four values — `error`, `warning`, `success`, `info`.
- **showCartSnackBar**: The global function in `cart_provider.dart` that currently calls
  `ScaffoldMessenger.of(context).showSnackBar(...)`. After the fix it delegates to
  `AppToast.show()`.
- **_QuantityStepper**: The `ConsumerWidget` in `product_option_bottom_sheet.dart` whose
  "+" handler silently returns when `quantity >= maxOrderQty`.
- **_mapCartErrorMessage**: The existing private function that sanitises raw backend
  strings; it is **preserved** and called by `AppToast` before rendering.
- **ScaffoldMessenger call site**: Any location in the codebase that calls
  `ScaffoldMessenger.of(context).showSnackBar(...)` or the local `_showSnackBar(...)`
  helper that wraps it.

---

## Bug Details

### Bug Condition

Two independent bug conditions are defined.

**Bug C₁ — Bottom Snackbar Renderer**

The bug manifests whenever a notification is shown via `ScaffoldMessenger` or the
`showCartSnackBar()` wrapper. The notification is rendered at the bottom of the screen
behind the navigation bar, without a type icon, and with no visual hierarchy between
severity levels.

```
FUNCTION isBugCondition_BottomSnackBar(X)
  INPUT: X of type NotificationEvent
  OUTPUT: boolean

  RETURN X.renderedVia = ScaffoldMessenger
      OR X.renderedVia = showCartSnackBar
END FUNCTION
```

**Bug C₂ — Silent Max-Quantity Rejection**

The bug manifests when the user taps "+" on a `_QuantityStepper` and the item is
already at its maximum allowed quantity. The handler returns silently with zero feedback.

```
FUNCTION isBugCondition_SilentMaxQty(X)
  INPUT: X of type QuantityStepEvent
  OUTPUT: boolean

  RETURN X.direction = increment
     AND X.currentQuantity >= (X.maxOrderQty ?? 50)
END FUNCTION
```

### Examples

**C₁ examples:**

- User adds a product to cart → backend returns an allocation error → bottom bar appears
  behind the nav tab, text reads raw backend string "shop_allocation_required".
  **Expected**: top toast with ⚠️ icon: "📍 Please set your delivery address to continue."

- User taps "Order cancelled" → small green bottom snackbar flashes at the very bottom.
  **Expected**: top toast with ✅ icon: "✅ Order cancelled successfully."

- Profile screen → "Payment settings" tapped → bottom bar "Coming soon" appears without
  any icon or colour.
  **Expected**: top toast with ℹ️ icon: "🚀 Coming soon!"

- Review form submitted without rating → bottom bar "Please select a rating" with no
  semantic styling.
  **Expected**: top warning toast: "⚠️ Please select a rating."

**C₂ example:**

- User has 5 of Product A in cart, `maxOrderQty = 5`. Tapping "+" does nothing —
  no visual response, no haptic, no message.
  **Expected**: warning toast "⚠️ Maximum 5 items allowed per order." before returning.

---

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviours:**

- Cart state (add, update, remove, clear, validate) continues to mutate `CartNotifier`
  exactly as before; `AppToast` is call-site decoration only.
- Quantity stepper decrement, and increment within `[1, maxOrderQty - 1]`, continues to
  work without any new feedback or delay.
- `_mapCartErrorMessage()` continues to sanitise raw backend strings before display; the
  mapped message becomes the `AppToast` body text.
- All routing (GoRouter), Riverpod provider state, and widget rebuild cycles are
  completely unaffected.
- Mouse/touch interactions on buttons, cards, and list tiles continue to work exactly
  as before.
- Auth flow, address selection, and checkout validation logic is unchanged.

**Scope:**

All inputs that do **not** satisfy `isBugCondition_BottomSnackBar(X)` or
`isBugCondition_SilentMaxQty(X)` must be completely unaffected. This includes:

- In-range quantity changes on the stepper
- Cart operations that complete successfully (no toast triggered by success paths
  unless the original code already showed a message)
- Screen navigation and deep-links
- All non-notification widget rendering

---

## Hypothesized Root Cause

### C₁ — Bottom Snackbar

1. **`ScaffoldMessenger` positioning**: Flutter's `ScaffoldMessenger` renders `SnackBar`
   widgets at the bottom of the nearest `Scaffold`. With a `BottomNavigationBar` present,
   the snackbar appears *behind* the tab bar, requiring `behavior: SnackBarBehavior.floating`
   even to be visible — and floating snackbars still anchor near the bottom.

2. **No type abstraction**: `showCartSnackBar` uses a single `bool isError` flag, which
   collapses four semantic levels (error / warning / success / info) into a binary
   red/green decision with no icon or emoji.

3. **Incomplete error sanitisation at call sites**: Outside of `cart_provider.dart` the
   15+ scattered call sites pass raw `failure.message` or literal strings directly to
   `ScaffoldMessenger` without going through `_mapCartErrorMessage`.

4. **`ScaffoldMessenger` coupling**: Each call site holds a direct reference to the
   `BuildContext`'s `ScaffoldMessenger`, which means the notification layer cannot be
   extracted without touching every call site.

### C₂ — Silent Max-Quantity

1. **Early return without feedback**: The `_QuantityStepper` "+" handler in
   `product_option_bottom_sheet.dart` contains `if (quantity >= (option.maxOrderQty ?? 50)) return;`
   with no preceding user feedback. The guard is correct in preventing an over-quantity
   cart update, but the UX consequence — a tap that silently does nothing — is the bug.

---

## Correctness Properties

Property 1: Bug Condition — Top Overlay Toast Rendering

_For any_ notification event `X` where `isBugCondition_BottomSnackBar(X)` returns true,
the fixed notification layer SHALL insert an `OverlayEntry` positioned at the **top** of
the viewport, with a rounded-corner card, a left accent border in the type colour, a
type-specific Phosphor icon, the sanitised message text, and SHALL auto-dismiss after
3–4 seconds. It SHALL NOT use `ScaffoldMessenger` or `SnackBar`.

**Validates: Requirements 2.1, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 2.11, 2.12**

Property 2: Bug Condition — Max-Quantity Warning Feedback

_For any_ quantity step event `X` where `isBugCondition_SilentMaxQty(X)` returns true,
the fixed `_QuantityStepper` SHALL call `AppToast.show()` with `ToastType.warning` and
message `"⚠️ Maximum ${X.maxOrderQty} items allowed per order"` **before** returning,
so the user receives visible feedback for the blocked tap.

**Validates: Requirements 2.2**

Property 3: Preservation — Non-Notification Behaviour Unchanged

_For any_ input `X` where `isBugCondition_BottomSnackBar(X)` is false **and**
`isBugCondition_SilentMaxQty(X)` is false, the fixed code SHALL produce the same
observable result as the original code — cart state, quantity, routing, and all widget
output remain unchanged.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8**

---

## Fix Implementation

### New File: `lib/core/utils/app_toast.dart`

Create the `AppToast` utility as a pure Dart class with a single static entry-point.

**`ToastType` enum:**
```
enum ToastType { error, warning, success, info }
```

**`AppToast.show()` signature:**
```
static void show(
  BuildContext context,
  String message, {
  ToastType? type,          // if null, auto-inferred from message content
  Duration duration,        // default: 3.5 seconds
})
```

**`_inferType()` helper (auto-type detection):**
```
FUNCTION _inferType(message)
  lower ← message.toLowerCase()

  IF lower CONTAINS ANY OF ["refresh token", "expired", "jwt", "unauthorized",
                             "not authenticated", "session", "sign in"] THEN
    RETURN ToastType.error

  IF lower CONTAINS ANY OF ["maximum", "max", "unavailable", "not available",
                             "set your delivery", "address required"] THEN
    RETURN ToastType.warning

  IF lower CONTAINS ANY OF ["successfully", "cancelled", "deleted", "added",
                             "saved", "updated", "removed"] THEN
    RETURN ToastType.success

  IF lower CONTAINS ANY OF ["coming soon"] THEN
    RETURN ToastType.info

  RETURN ToastType.error  // safe default
END FUNCTION
```

**Type-to-visual mapping:**

| `ToastType` | Emoji | Phosphor Icon | Background tint | Accent colour |
|-------------|-------|---------------|-----------------|---------------|
| `error`     | ❌    | `PhosphorIcons.xCircle()` | `AppColors.errorRed.withOpacity(0.08)` | `AppColors.errorRed` |
| `warning`   | ⚠️    | `PhosphorIcons.warning()` | `AppColors.warningOrange.withOpacity(0.08)` | `AppColors.warningOrange` |
| `success`   | ✅    | `PhosphorIcons.checkCircle()` | `AppColors.successGreen.withOpacity(0.08)` | `AppColors.successGreen` |
| `info`      | ℹ️    | `PhosphorIcons.info()` | `AppColors.infoBlue.withOpacity(0.08)` | `AppColors.infoBlue` |

**Overlay insertion pseudocode:**
```
FUNCTION show(context, message, type, duration)
  resolvedType ← type ?? _inferType(message)
  overlay      ← Overlay.of(context)

  // Remove existing toast (no stacking)
  _currentEntry?.remove()
  _currentEntry ← null

  controller ← AnimationController(vsync: overlay, duration: 300ms)
  entry ← OverlayEntry(
    builder: (_) → SafeArea(
      child: Padding(top: 12.h, horizontal: 16.w,
        child: GestureDetector(
          onTap: () → _dismiss(controller, entry),
          child: SlideTransition(
            position: Tween<Offset>(begin: Offset(0, -1), end: Offset.zero)
                        .animate(CurvedAnimation(controller, Curves.easeOutCubic)),
            child: FadeTransition(
              opacity: controller,
              child: _ToastCard(message, resolvedType),
            ),
          ),
        ),
      ),
    ),
  )

  _currentEntry ← entry
  overlay.insert(entry)
  controller.forward()

  Timer(duration, () → _dismiss(controller, entry))
END FUNCTION

FUNCTION _dismiss(controller, entry)
  controller.reverse().then((_) →
    entry.remove()
    if (_currentEntry == entry) _currentEntry ← null
  )
END FUNCTION
```

**`_ToastCard` widget layout:**
```
Container(
  decoration: BoxDecoration(
    color: tintedBackground,
    borderRadius: BorderRadius.circular(14.r),
    border: Border(left: BorderSide(color: accentColour, width: 4.w)),
    boxShadow: [BoxShadow(color: 0x1A000000, blurRadius: 12, offset: Offset(0, 4))],
  ),
  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
  child: Row(
    children: [
      PhosphorIcon(icon, size: 20.sp, color: accentColour),
      Gap(10.w),
      Expanded(
        child: Text(message, style: AppTextStyles.bodyMedium.copyWith(
          fontWeight: FontWeight.w600, color: AppColors.textPrimary,
        )),
      ),
    ],
  ),
)
```

---

### Changes Required

**File 1: `lib/features/cart/presentation/providers/cart_provider.dart`**

- **Update `showCartSnackBar`**: Remove the `ScaffoldMessenger` call. Call
  `AppToast.show(context, displayMessage)` instead. The `isError` parameter is deprecated
  — type is auto-detected from message content. Keep `_mapCartErrorMessage` and call it
  before delegating, exactly as today.

  ```dart
  void showCartSnackBar(BuildContext context, String message, {bool isError = true}) {
    final displayMessage = _mapCartErrorMessage(message);
    AppToast.show(context, displayMessage);
  }
  ```

**File 2: `lib/features/products/presentation/widgets/product_option_bottom_sheet.dart`**

- **Fix silent max-qty guard**: In `_QuantityStepper`'s "+" `onTap`, add a toast call
  before the early return:

  ```dart
  onTap: () async {
    if (quantity >= (option.maxOrderQty ?? 50)) {
      AppToast.show(
        context,
        '⚠️ Maximum ${option.maxOrderQty ?? 50} items allowed per order',
        type: ToastType.warning,
      );
      return;
    }
    // ... existing update logic
  },
  ```

- **Replace `showCartSnackBar` calls** in the ADD button and stepper with
  `AppToast.show(context, result.failure!.message)`.

**File 3: `lib/features/cart/presentation/screens/cart_screen.dart`**

- All 5 existing `showCartSnackBar(...)` calls remain syntactically valid after File 1's
  change — no code edits needed at these sites.

**Files 4–13: Direct `ScaffoldMessenger` / `_showSnackBar` call sites**

Replace each call with the equivalent `AppToast.show()`. Apply type overrides where the
correct type can be determined statically:

| File | Current call | Replacement |
|------|-------------|-------------|
| `orders_screen.dart` | `_showSnackBar(failure.message)` | `AppToast.show(context, failure.message)` |
| `orders_screen.dart` | `_showSnackBar('Order cancelled successfully')` | `AppToast.show(context, '✅ Order cancelled successfully', type: ToastType.success)` |
| `orders_screen.dart` | `ScaffoldMessenger.showSnackBar(SnackBar(...items added to cart...))` | `AppToast.show(context, 'Items added to cart$warnings', type: ToastType.success)` |
| `order_detail_screen.dart` | `ScaffoldMessenger.showSnackBar(SnackBar(failure.message))` (×3) | `AppToast.show(context, failure.message)` |
| `order_detail_screen.dart` | `'Order cancelled successfully'` | `AppToast.show(context, '✅ Order cancelled successfully', type: ToastType.success)` |
| `notifications_screen.dart` | `ScaffoldMessenger.showSnackBar(SnackBar(result.failure!.message))` (×3) | `AppToast.show(context, result.failure!.message)` |
| `profile_screen.dart` | `ScaffoldMessenger.showSnackBar(SnackBar(message))` (error from state) | `AppToast.show(context, message)` |
| `profile_screen.dart` | `'Coming soon'` (×2) | `AppToast.show(context, '🚀 Coming soon!', type: ToastType.info)` |
| `profile_screen.dart` | `ScaffoldMessenger.showSnackBar(failure.message)` (×2) | `AppToast.show(context, result.failure!.message)` |
| `address_list_screen.dart` | `messenger.showSnackBar(...)` (×2) | `AppToast.show(context, ...)` with `type: ToastType.success` for "Address deleted." |
| `add_edit_address_screen.dart` | `_showSnackBar(...)` (×3) | `AppToast.show(context, ...)` |
| `checkout_screen.dart` | `_showSnackBar(msg, isError: true)`, etc. (×3) | `AppToast.show(context, msg)` |
| `write_review_screen.dart` | `ScaffoldMessenger.showSnackBar(...)` (×2) | `AppToast.show(context, ...)` |
| `wallet/topup_screen.dart` | `ScaffoldMessenger.showSnackBar(...)` (×5) | `AppToast.show(context, ...)` |

---

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, write tests that run against
the **unfixed** code to surface counterexamples and confirm root cause analysis; then
verify the fix works correctly and that preservation holds.

---

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples demonstrating both bugs **before** the fix is applied.
Confirm or refute the root cause analysis. If refuted, re-hypothesize.

**Test Plan**: Write widget tests that trigger a notification event or a max-qty stepper
tap, then assert on the widget tree. On unfixed code these assertions should **fail**,
confirming the bug.

**Test Cases:**

1. **C₁ — Cart error renders via ScaffoldMessenger** (fails on unfixed code):
   Pump `CartScreen`, simulate a cart-add failure. Assert that no `SnackBar` widget
   appears in the tree and that an `AppToast`-style overlay card exists.

2. **C₁ — "Coming soon" renders via ScaffoldMessenger** (fails on unfixed code):
   Pump `ProfileScreen`, tap "Payment settings". Assert no `SnackBar`, expect top card
   with info styling.

3. **C₂ — Max-qty tap is silent** (fails on unfixed code):
   Pump `ProductOptionBottomSheet` with a product already at `maxOrderQty`. Tap "+".
   Assert that an overlay warning card is displayed.

4. **C₂ — Edge case: maxOrderQty is null (defaults to 50)** (may fail on unfixed code):
   Same test with `maxOrderQty = null` and `currentQuantity = 50`.

**Expected Counterexamples:**
- A `SnackBar` widget is found in the widget tree instead of an overlay card.
- No toast appears at all for the max-qty tap.
- The overlay card (if any) is positioned at the bottom, not the top.

---

### Fix Checking

**Goal**: Verify that for all inputs where either bug condition holds, the fixed code
produces the expected overlay-toast behaviour.

**Pseudocode:**
```
// Property 1
FOR ALL X WHERE isBugCondition_BottomSnackBar(X) DO
  result ← AppToast.show'(X)
  ASSERT result.positionedAt = TOP
  ASSERT result.renderedVia = Overlay
  ASSERT result.hasIcon = true
  ASSERT result.message IS user_friendly(X.rawMessage)
  ASSERT result.autoDismissAfter IN [3s, 4s]
END FOR

// Property 2
FOR ALL X WHERE isBugCondition_SilentMaxQty(X) DO
  result ← quantityStepper.onIncrement'(X)
  ASSERT result.toastShown = true
  ASSERT result.toastType = warning
  ASSERT result.toastMessage CONTAINS "Maximum"
  ASSERT result.toastMessage CONTAINS string(X.maxOrderQty ?? 50)
END FOR
```

---

### Preservation Checking

**Goal**: Verify that for all inputs where neither bug condition holds, the fixed code
produces the same observable result as the original code.

**Pseudocode:**
```
FOR ALL X WHERE NOT isBugCondition_BottomSnackBar(X)
              AND NOT isBugCondition_SilentMaxQty(X) DO
  ASSERT F(X) = F'(X)   // cart state, UI, routing unchanged
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking
because:
- It generates many random cart states and input sequences automatically.
- It catches edge cases (empty cart, single-item cart, multi-store carts) that manual
  unit tests miss.
- It provides strong guarantees that the notification-layer change has not accidentally
  altered cart mutation logic.

**Test Plan**: Observe behaviour on the **unfixed** code for in-range stepper taps and
successful cart operations, capture expected state, then write property-based tests that
verify the same state is produced by the fixed code.

**Test Cases:**

1. **In-range quantity increment preservation**: For `quantity` in `[1, maxOrderQty - 1]`,
   tapping "+" must call `cartProvider.updateItem(id, quantity + 1)` exactly once and
   show **no** toast. Verify on unfixed and fixed code.

2. **Successful cart-add preservation**: A successful `cartProvider.addItem()` must
   update cart state and emit **no** notification toast. Verify cart item count
   increments correctly.

3. **Successful order-cancel preservation**: Cancelling an order updates order list state
   and **does** emit a success toast (behaviour changed from bottom to top) but
   `orderListProvider` state is unchanged.

4. **ScaffoldMessenger not called after fix**: Assert that after the fix no widget test
   ever sees a `SnackBar` in the tree.

---

### Unit Tests

- Test `AppToast._inferType()` for each category: session errors, max-qty strings,
  success strings, info strings, unknown strings.
- Test `_mapCartErrorMessage()` continues to map raw strings correctly (existing
  behaviour, zero changes expected).
- Test `AppToast.show()` with each `ToastType` — assert correct icon, colour, and
  accent are applied to the rendered `_ToastCard`.
- Test auto-dismiss: after `duration` elapses the overlay entry is removed.
- Test tap-to-dismiss: tapping the card removes the overlay entry before auto-dismiss.
- Test queue/replace: calling `AppToast.show()` twice quickly removes the first entry
  before inserting the second (no card stacking).

---

### Property-Based Tests

- **Type inference is total**: For any non-empty string input, `_inferType` returns one
  of the four `ToastType` values and never throws.
- **Overlay count invariant**: After any sequence of `AppToast.show()` calls at most one
  `_ToastCard` widget exists in the overlay at any moment.
- **Preservation of cart state**: Generate random sequences of `addItem / updateItem /
  removeItem` operations with random in-range quantities; assert that the `CartEntity`
  produced by fixed code equals that of original code (modulo presentation).
- **Stepper preservation for valid increments**: For any `(currentQuantity, maxOrderQty)`
  pair where `currentQuantity < maxOrderQty`, incrementing the stepper must not produce
  a toast and must call `updateItem` with `currentQuantity + 1`.

---

### Integration Tests

- Full cart flow: add product → update quantity to max → tap "+" → assert warning toast
  appears at top → assert cart quantity unchanged.
- Order cancellation flow: cancel an active order → assert success toast appears at the
  top with green accent → assert order list refreshes.
- Profile "Coming soon" flow: tap "Payment settings" → assert info toast appears with
  `infoBlue` accent.
- Context switching: navigate from `CartScreen` → `OrdersScreen` → `ProfileScreen` while
  triggering toasts; assert no `SnackBar` appears anywhere in the navigation stack.
- Overlay independence: dismiss the keyboard or a `BottomSheet` mid-toast; assert the
  toast continues to render correctly above both.
