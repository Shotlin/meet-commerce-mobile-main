# Bugfix Requirements Document

## Introduction

The Bakaloo Flutter app currently surfaces all user notifications — cart errors, session
warnings, success confirmations, and info messages — as default Flutter `SnackBar` widgets
via `showCartSnackBar()` and scattered `ScaffoldMessenger.of(context).showSnackBar()` calls.
These bottom bars appear behind the bottom navigation, carry no icons or emojis, expose
raw technical server strings to users, and have no visual hierarchy between error, warning,
success, and info severity levels.

A second, distinct bug exists in the product option bottom sheet: when the user taps "+"
and the item is already at its maximum allowed quantity, the handler silently returns with
no feedback at all — the user has no idea why their tap did nothing.

This fix replaces the entire notification layer with a premium `AppToast` utility that
slides in from the top of the screen, uses type-aware icons and colour schemes, shows
user-friendly copy, auto-dismisses after a few seconds, and is fully independent of the
`Scaffold`/`ScaffoldMessenger` stack.

---

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN any cart action fails (add item, update quantity, remove item, clear cart,
    or checkout validation) THEN the system shows a plain red/green bar at the **bottom**
    of the screen that is partially covered by the bottom navigation bar

1.2 WHEN a user taps "+" in the `_QuantityStepper` inside `product_option_bottom_sheet.dart`
    and the item is already at its maximum allowed quantity (`quantity >= option.maxOrderQty ?? 50`)
    THEN the system silently returns with no user feedback whatsoever

1.3 WHEN any notification is shown via `showCartSnackBar()` or a direct
    `ScaffoldMessenger.of(context).showSnackBar()` call THEN the system renders a plain
    coloured rectangle with no icon, no emoji, and no semantic differentiation between
    error, warning, success, and info notification types

1.4 WHEN backend or session errors occur (e.g. "Invalid or expired refresh token", JWT
    errors, UUID syntax errors) THEN the system surfaces near-technical error text to
    the user even after the partial `_mapCartErrorMessage()` mapping

1.5 WHEN notifications are shown across multiple screens (`orders_screen.dart`,
    `order_detail_screen.dart`, `profile_screen.dart`, `notifications_screen.dart`,
    `write_review_screen.dart`, `address_list_screen.dart`) THEN the system uses raw
    `showSnackBar()` calls that bypass the cart error mapper entirely and expose
    unfiltered strings to users

1.6 WHEN a validation result contains multiple warnings from `validateAndProceed()`
    THEN the system shows them joined by `\n` as a single bottom snackbar with no
    structured formatting

### Expected Behavior (Correct)

2.1 WHEN any cart action fails THEN the system SHALL show a top-positioned notification
    that slides in from above and does **not** overlap the bottom navigation bar

2.2 WHEN a user taps "+" in the quantity stepper and the item is already at its
    maximum allowed quantity THEN the system SHALL show a warning toast:
    "⚠️ Maximum [N] items allowed per order"

2.3 WHEN any notification is shown THEN the system SHALL render a premium card with
    rounded corners, a drop shadow, type-appropriate emoji/icon, and a smooth
    slide-in animation from the top of the screen

2.4 WHEN a notification type is **error** THEN the system SHALL use the ❌ icon and
    `AppColors.errorRed` colour scheme (e.g. "❌ Something went wrong. Please try again.")

2.5 WHEN a notification type is **warning** THEN the system SHALL use the ⚠️ icon and
    `AppColors.warningOrange` colour scheme (e.g. max-quantity, product unavailable)

2.6 WHEN a notification type is **success** THEN the system SHALL use the ✅ icon and
    `AppColors.successGreen` colour scheme (e.g. "✅ Address saved successfully")

2.7 WHEN a notification type is **info** THEN the system SHALL use the ℹ️ icon and
    `AppColors.infoBlue` colour scheme (e.g. "🚀 Coming soon!")

2.8 WHEN an auth or session error is detected (refresh token, JWT, unauthorized,
    "session has expired") THEN the system SHALL show an error toast:
    "🔐 Session expired. Please sign in again."

2.9 WHEN a product-unavailability error is detected THEN the system SHALL show a
    warning toast: "📍 This product isn't available at your location."

2.10 WHEN a delivery address is required but missing THEN the system SHALL show a
     warning toast: "📍 Please set your delivery address to continue."

2.11 WHEN a notification is displayed THEN the system SHALL auto-dismiss it after
     3–4 seconds AND SHALL dismiss it immediately when the user taps it

2.12 WHEN a notification is shown THEN the system SHALL use a Flutter `Overlay` entry
     positioned at the top of the viewport — **not** `ScaffoldMessenger` or `SnackBar` —
     so placement is independent of the `Scaffold` layout tree

2.13 WHEN multiple notification calls happen in quick succession THEN the system SHALL
     queue or replace the current toast so overlapping cards are not stacked on screen

### Unchanged Behavior (Regression Prevention)

3.1 WHEN a cart action (add, update, remove, clear) succeeds THEN the system SHALL
    CONTINUE TO update cart state and re-render the UI without interruption

3.2 WHEN a user taps ADD on a product that is in stock and below the maximum quantity
    THEN the system SHALL CONTINUE TO add the item to the cart and increment the
    displayed quantity

3.3 WHEN a quantity stepper is used and the current quantity is between 1 and
    `(maxOrderQty - 1)` THEN the system SHALL CONTINUE TO allow incrementing and
    decrementing normally

3.4 WHEN a user is not authenticated and attempts a cart action THEN the system SHALL
    CONTINUE TO surface an auth-related notification prompting them to sign in

3.5 WHEN `_mapCartErrorMessage()` maps a raw backend string to a user-friendly message
    THEN the system SHALL CONTINUE TO use that mapped message as the toast body text

3.6 WHEN the cart validation detects removed or price-changed items THEN the system
    SHALL CONTINUE TO refresh cart state and notify the user of the change

3.7 WHEN a "coming soon" or unimplemented feature is tapped THEN the system SHALL
    CONTINUE TO show a notification; it SHALL use an info toast instead of a snackbar

3.8 WHEN review submission, address management, or order actions succeed or fail THEN
    the system SHALL CONTINUE TO communicate the outcome to the user; only the
    presentation layer changes from bottom snackbar to top toast

---

## Bug Condition Pseudocode

### Bug Condition Functions

```pascal
// Bug 1 — Bottom snackbar renderer
FUNCTION isBugCondition_BottomSnackBar(X)
  INPUT: X of type NotificationEvent
  OUTPUT: boolean

  // Fires whenever a notification is shown via the current broken path
  RETURN X.renderedVia = ScaffoldMessenger
      OR X.renderedVia = showCartSnackBar
END FUNCTION

// Bug 2 — Silent max-quantity rejection
FUNCTION isBugCondition_SilentMaxQty(X)
  INPUT: X of type QuantityStepEvent
  OUTPUT: boolean

  RETURN X.direction = increment
     AND X.currentQuantity >= X.maxOrderQty
END FUNCTION
```

### Fix-Checking Properties

```pascal
// Property: Fix Checking — Bottom Snackbar Replacement
FOR ALL X WHERE isBugCondition_BottomSnackBar(X) DO
  result ← AppToast.show'(X)
  ASSERT result.positionedAt = TOP
  ASSERT result.renderedVia = Overlay
  ASSERT result.hasIcon = true
  ASSERT result.message IS user_friendly(X.rawMessage)
  ASSERT result.autoDismissAfter IN [3s, 4s]
END FOR

// Property: Fix Checking — Max Quantity Feedback
FOR ALL X WHERE isBugCondition_SilentMaxQty(X) DO
  result ← quantityStepper.onIncrement'(X)
  ASSERT result.toastShown = true
  ASSERT result.toastType = warning
  ASSERT result.toastMessage CONTAINS "Maximum"
  ASSERT result.toastMessage CONTAINS string(X.maxOrderQty)
END FOR
```

### Preservation Property

```pascal
// Property: Preservation Checking
FOR ALL X WHERE NOT isBugCondition_BottomSnackBar(X)
              AND NOT isBugCondition_SilentMaxQty(X) DO
  ASSERT F(X) = F'(X)   // cart state, UI, routing unchanged
END FOR
```
