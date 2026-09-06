#!/usr/bin/env bash
# ============================================================
# Bakaloo — Launch App on Emulators
# Usage: bash scripts/run_emulator.sh [android|ios|both]
#        bash scripts/run_emulator.sh android --release
# ============================================================

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TARGET="${1:-both}"
BUILD_MODE="${2:---debug}"

if [ -z "${ANDROID_HOME:-}" ]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
fi

launch_android() {
  echo "🤖 Launching Android emulator..."

  # Check if emulator is already running
  RUNNING=$(flutter devices 2>/dev/null | grep emulator || true)

  if [ -z "$RUNNING" ]; then
    echo "   Starting Pixel 8 emulator..."
    "$ANDROID_HOME/emulator/emulator" -avd Pixel_8_API_35 -no-audio -no-snapshot &
    EMULATOR_PID=$!

    echo "   Waiting for emulator to boot..."
    ADB="$ANDROID_HOME/platform-tools/adb"
    for i in {1..60}; do
      BOOT=$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)
      if [ "$BOOT" = "1" ]; then
        echo "   ✅ Emulator booted!"
        break
      fi
      echo "   Waiting... ($i/60)"
      sleep 3
    done
  else
    echo "   ✅ Emulator already running"
  fi

  echo ""
  echo "📱 Running app on Android emulator ($BUILD_MODE)..."
  if [ "$BUILD_MODE" = "--release" ]; then
    flutter run --release -d emulator-5554
  else
    flutter run -d emulator-5554
  fi
}

launch_ios() {
  echo "🍎 Launching iOS simulator..."

  # Boot iPhone 16 Pro simulator
  DEVICE_ID=$(xcrun simctl list devices | grep "iPhone 16 Pro" | grep -v "Plus\|Max" | grep -v "Unavailable" | head -1 | grep -oE '[A-F0-9-]{36}')

  if [ -z "$DEVICE_ID" ]; then
    echo "   iPhone 16 Pro not found, using first available iPhone..."
    DEVICE_ID=$(xcrun simctl list devices | grep "iPhone" | grep -v "Unavailable" | head -1 | grep -oE '[A-F0-9-]{36}')
  fi

  if [ -z "$DEVICE_ID" ]; then
    echo "❌ No iOS simulator found. Open Xcode → Window → Devices and Simulators to create one."
    exit 1
  fi

  echo "   Booting simulator: $DEVICE_ID"
  xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
  open -a Simulator

  echo ""
  echo "📱 Running app on iOS simulator ($BUILD_MODE)..."
  if [ "$BUILD_MODE" = "--release" ]; then
    flutter run --release -d "$DEVICE_ID"
  else
    flutter run -d "$DEVICE_ID"
  fi
}

# ── Main ──────────────────────────────────────────────────────
echo "============================================================"
echo "  Bakaloo — Run on Emulator"
echo "  Target: $TARGET  |  Mode: $BUILD_MODE"
echo "============================================================"
echo ""

flutter pub get

case "$TARGET" in
  android)
    launch_android
    ;;
  ios)
    launch_ios
    ;;
  both)
    echo "ℹ️  Running on both emulators simultaneously..."
    echo "   Start Android first, then iOS in a new terminal:"
    echo ""
    echo "   Terminal 1: bash scripts/run_emulator.sh android"
    echo "   Terminal 2: bash scripts/run_emulator.sh ios"
    echo ""
    launch_android
    ;;
  *)
    echo "Usage: $0 [android|ios|both] [--debug|--release]"
    exit 1
    ;;
esac
