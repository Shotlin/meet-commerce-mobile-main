#!/usr/bin/env bash
# ============================================================
# Bakaloo — Android Emulator Setup
# Creates a Pixel 8 emulator with API 35 (Android 15)
# ============================================================

set -euo pipefail

echo "📱 Setting up Android emulator..."
echo ""

# Check Android SDK
if [ -z "${ANDROID_HOME:-}" ]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
fi

SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
AVDMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager"
EMULATOR="$ANDROID_HOME/emulator/emulator"

if [ ! -f "$SDKMANAGER" ]; then
  echo "❌ sdkmanager not found at $SDKMANAGER"
  echo "   Please complete Android Studio setup first (run the Setup Wizard)."
  exit 1
fi

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  ABI="arm64-v8a"
  echo "   Detected: Apple Silicon (arm64)"
else
  ABI="x86_64"
  echo "   Detected: Intel (x86_64)"
fi

SYSTEM_IMAGE="system-images;android-35;google_apis_playstore;$ABI"
AVD_NAME="Pixel_8_API_35"

echo ""
echo "1️⃣  Installing Android 35 system image ($ABI)..."
echo "y" | "$SDKMANAGER" "$SYSTEM_IMAGE"

echo ""
echo "2️⃣  Accepting licenses..."
echo "y" | "$SDKMANAGER" --licenses

echo ""
echo "3️⃣  Creating AVD: $AVD_NAME..."
if "$AVDMANAGER" list avd | grep -q "$AVD_NAME"; then
  echo "   AVD '$AVD_NAME' already exists, skipping creation."
else
  echo "no" | "$AVDMANAGER" create avd \
    -n "$AVD_NAME" \
    -k "$SYSTEM_IMAGE" \
    -d "pixel_8"
  echo "   ✅ AVD created!"
fi

echo ""
echo "✅ Android emulator setup complete!"
echo ""
echo "To start the emulator:"
echo "   flutter emulators --launch $AVD_NAME"
echo "   # or"
echo "   $EMULATOR -avd $AVD_NAME &"
echo ""
echo "Then run the app:"
echo "   flutter run -d emulator-5554"
