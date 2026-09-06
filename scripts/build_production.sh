#!/usr/bin/env bash
# ============================================================
# Bakaloo — Full Production Build Script
# Builds: Android APK, Android App Bundle, iOS Release
# ============================================================

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="$ROOT/build/production"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')

echo "============================================================"
echo "  Bakaloo Production Build"
echo "  Version: $VERSION"
echo "  Time: $TIMESTAMP"
echo "============================================================"
echo ""

# ── Verify keystore exists ────────────────────────────────────
KEYSTORE="$ROOT/android/app/bakaloo-release.jks"
if [ ! -f "$KEYSTORE" ]; then
  echo "❌ Release keystore not found: $KEYSTORE"
  echo "   Run: bash scripts/generate_keystore.sh"
  exit 1
fi
echo "✅ Keystore found"

# ── Clean previous build ──────────────────────────────────────
echo ""
echo "🧹 Cleaning previous build..."
flutter clean
mkdir -p "$BUILD_DIR"

# ── Get dependencies ──────────────────────────────────────────
echo ""
echo "📦 Getting Flutter dependencies..."
flutter pub get

# ── iOS: pod install ──────────────────────────────────────────
if command -v pod &>/dev/null; then
  echo ""
  echo "🍎 Installing CocoaPods..."
  cd ios
  pod install --repo-update
  cd "$ROOT"
else
  echo "⚠️  CocoaPods not found — skipping iOS pod install"
fi

# ── Debug symbols (Dart obfuscation) ───────────────────────────
# --obfuscate strips/renames Dart-level symbols (class/method names,
# including payment logic) from the shipped binary so it isn't readable
# straight out of a decompiled APK. --split-debug-info writes the mapping
# needed to decode a future stack trace back to real symbols — WITHOUT
# this saved, an obfuscated build's crash reports are permanently
# unreadable gibberish. Keep this whole directory (back it up outside the
# repo) for as long as this build's version code might still be installed
# on a user's device.
SYMBOLS_DIR="$BUILD_DIR/debug-symbols-$VERSION-$TIMESTAMP"
mkdir -p "$SYMBOLS_DIR/android-apk" "$SYMBOLS_DIR/android-aab" "$SYMBOLS_DIR/ios"

# ── Build Android APK ─────────────────────────────────────────
echo ""
echo "🤖 Building Android APK (release, obfuscated)..."
flutter build apk --release --obfuscate --split-debug-info="$SYMBOLS_DIR/android-apk"
APK_SRC="$ROOT/build/app/outputs/flutter-apk/app-release.apk"
APK_DST="$BUILD_DIR/bakaloo-$VERSION-$TIMESTAMP.apk"
cp "$APK_SRC" "$APK_DST"
echo "   ✅ APK: $APK_DST"

# ── Build Android App Bundle ──────────────────────────────────
echo ""
echo "🤖 Building Android App Bundle (release, obfuscated)..."
flutter build appbundle --release --obfuscate --split-debug-info="$SYMBOLS_DIR/android-aab"
AAB_SRC="$ROOT/build/app/outputs/bundle/release/app-release.aab"
AAB_DST="$BUILD_DIR/bakaloo-$VERSION-$TIMESTAMP.aab"
cp "$AAB_SRC" "$AAB_DST"
echo "   ✅ AAB: $AAB_DST"

# ── Build iOS ─────────────────────────────────────────────────
echo ""
echo "🍎 Building iOS (release, no codesign, obfuscated)..."
if xcode-select -p &>/dev/null && [ -d /Applications/Xcode.app ]; then
  flutter build ios --release --no-codesign --obfuscate --split-debug-info="$SYMBOLS_DIR/ios"
  IOS_BUILD="$ROOT/build/ios/iphoneos/Runner.app"
  if [ -d "$IOS_BUILD" ]; then
    IOS_DST="$BUILD_DIR/bakaloo-$VERSION-$TIMESTAMP-ios.app"
    cp -r "$IOS_BUILD" "$IOS_DST"
    echo "   ✅ iOS build: $IOS_DST"
    echo ""
    echo "   📤 To upload to App Store:"
    echo "      open ios/Runner.xcworkspace"
    echo "      Then: Product → Archive → Distribute App"
  fi
else
  echo "   ⚠️  Xcode not found — skipping iOS build"
fi

# ── Summary ───────────────────────────────────────────────────
echo ""
echo "============================================================"
echo "  ✅ Production Build Complete!"
echo "  Output directory: $BUILD_DIR"
echo ""
ls -lh "$BUILD_DIR" 2>/dev/null || true
echo "============================================================"
