#!/usr/bin/env bash
# ============================================================
# Bakaloo — ONE-SHOT Full Environment Installer
# Run this AFTER Homebrew and Xcode are installed.
# This handles everything else automatically.
# ============================================================

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "============================================================"
echo "  Bakaloo Flutter — Full Environment Setup"
echo "  macOS $(sw_vers -productVersion) | $(uname -m)"
echo "============================================================"
echo ""

# ── Homebrew check ────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  echo "❌ Homebrew not found."
  echo "   Install it first:"
  echo '   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  echo "   Then re-run this script."
  exit 1
fi
echo "✅ Homebrew: $(brew --version | head -1)"

# ── Xcode check ───────────────────────────────────────────────
if ! xcode-select -p 2>/dev/null | grep -q "Xcode.app"; then
  echo "❌ Xcode not found or not set as active developer directory."
  echo "   1. Install Xcode from Mac App Store"
  echo "   2. Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  echo "   3. Run: sudo xcodebuild -license accept"
  echo "   Then re-run this script."
  exit 1
fi
echo "✅ Xcode: $(xcodebuild -version 2>/dev/null | head -1)"

# ── Flutter ───────────────────────────────────────────────────
if ! command -v flutter &>/dev/null; then
  echo ""
  echo "📥 Installing Flutter SDK..."
  brew install --cask flutter
  # Reload PATH
  export PATH="$HOME/flutter/bin:$PATH"
  eval "$(brew shellenv 2>/dev/null || true)"
else
  echo "✅ Flutter: $(flutter --version 2>/dev/null | head -1)"
fi

# ── JDK 17 ────────────────────────────────────────────────────
if ! java -version 2>&1 | grep -q "17\|21"; then
  echo ""
  echo "📥 Installing JDK 17..."
  brew install openjdk@17
fi

# Set JAVA_HOME
JAVA_HOME_PATH="$(brew --prefix openjdk@17 2>/dev/null || echo "/opt/homebrew/opt/openjdk@17")"
export JAVA_HOME="$JAVA_HOME_PATH"
export PATH="$JAVA_HOME/bin:$PATH"

# Persist to shell profile
if ! grep -q "openjdk@17" ~/.zshrc 2>/dev/null; then
  echo "" >> ~/.zshrc
  echo "# JDK 17 (for Flutter/Android)" >> ~/.zshrc
  echo "export JAVA_HOME=\"$JAVA_HOME_PATH\"" >> ~/.zshrc
  echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> ~/.zshrc
fi
echo "✅ Java: $(java -version 2>&1 | head -1)"

# ── Android Studio ────────────────────────────────────────────
if [ ! -d "/Applications/Android Studio.app" ]; then
  echo ""
  echo "📥 Installing Android Studio..."
  brew install --cask android-studio
  echo ""
  echo "⚠️  ACTION REQUIRED:"
  echo "   Open Android Studio and complete the Setup Wizard (choose 'Standard')."
  echo "   It will download the Android SDK, emulator, and build tools."
  echo "   Then press ENTER here to continue..."
  read -r
fi
echo "✅ Android Studio found"

# ── Android SDK path ──────────────────────────────────────────
ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
if [ -d "$ANDROID_HOME" ]; then
  export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

  if ! grep -q "ANDROID_HOME" ~/.zshrc 2>/dev/null; then
    echo "" >> ~/.zshrc
    echo "# Android SDK" >> ~/.zshrc
    echo "export ANDROID_HOME=\"\$HOME/Library/Android/sdk\"" >> ~/.zshrc
    echo 'export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"' >> ~/.zshrc
  fi
  echo "✅ Android SDK: $ANDROID_HOME"
else
  echo "⚠️  Android SDK not found at $ANDROID_HOME"
  echo "   Complete Android Studio setup first."
fi

# ── CocoaPods ─────────────────────────────────────────────────
if ! command -v pod &>/dev/null; then
  echo ""
  echo "📥 Installing CocoaPods..."
  sudo gem install cocoapods
fi
echo "✅ CocoaPods: $(pod --version)"

# ── Accept Android Licenses ───────────────────────────────────
echo ""
echo "📋 Accepting Android SDK licenses..."
if command -v sdkmanager &>/dev/null; then
  yes | flutter doctor --android-licenses 2>/dev/null || true
else
  echo "   ⚠️  sdkmanager not in PATH — run 'flutter doctor --android-licenses' manually after Android Studio setup"
fi

# ── Flutter pub get ───────────────────────────────────────────
echo ""
echo "📦 Installing Flutter packages..."
cd "$ROOT"
flutter pub get

# ── Code generation ───────────────────────────────────────────
echo ""
echo "⚙️  Running code generators..."
cd "$ROOT"
dart run build_runner build --delete-conflicting-outputs

# ── CocoaPods for iOS ─────────────────────────────────────────
echo ""
echo "🍎 Installing iOS CocoaPods..."
cd "$ROOT/ios"
pod install --repo-update
cd "$ROOT"

# ── Generate keystore ─────────────────────────────────────────
echo ""
echo "🔑 Setting up Android release keystore..."
bash "$ROOT/scripts/generate_keystore.sh"

# ── Create Android emulator ───────────────────────────────────
echo ""
echo "📱 Setting up Android emulator..."
bash "$ROOT/scripts/setup_emulators.sh" || echo "   ⚠️  Emulator setup needs Android SDK — run setup_emulators.sh manually after Android Studio setup"

# ── Final doctor check ────────────────────────────────────────
echo ""
echo "🏥 Flutter Doctor:"
flutter doctor

echo ""
echo "============================================================"
echo "  ✅ Environment setup complete!"
echo ""
echo "  Next steps:"
echo "  1. Run on Android: bash scripts/run_emulator.sh android"
echo "  2. Run on iOS:     bash scripts/run_emulator.sh ios"
echo "  3. Production build: bash scripts/build_production.sh"
echo "============================================================"
