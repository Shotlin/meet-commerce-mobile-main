# Bakaloo Flutter App — Full Environment Setup Guide

## Prerequisites Checklist

- [ ] macOS 13+ (Ventura or newer recommended)
- [ ] Xcode 15+ installed from Mac App Store
- [ ] Homebrew installed
- [ ] Flutter SDK installed
- [ ] Android Studio installed + SDK configured
- [ ] JDK 17 installed
- [ ] CocoaPods installed

---

## Step 1 — Install Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

After install, add to PATH (run the two lines Homebrew prints at the end):
```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
eval "$(/opt/homebrew/bin/brew shellenv)"
```

---

## Step 2 — Install Xcode (Mac App Store)

1. Open **App Store** → search **Xcode** → Install (~8 GB)
2. Open Xcode once, accept the license agreement
3. Run:
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

---

## Step 3 — Install All Tools via Homebrew

```bash
# Flutter SDK
brew install --cask flutter

# Android Studio (includes Android SDK)
brew install --cask android-studio

# JDK 17 (required for Android builds)
brew install openjdk@17
echo 'export JAVA_HOME=/opt/homebrew/opt/openjdk@17' >> ~/.zshrc
echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# CocoaPods (for iOS dependencies)
sudo gem install cocoapods
```

---

## Step 4 — Android Studio Setup

1. Open **Android Studio** from /Applications
2. Complete the **Setup Wizard** → choose **Standard**
3. It will download: Android SDK, Emulator, Build Tools, Platform Tools
4. After wizard completes, set ANDROID_HOME:
```bash
echo 'export ANDROID_HOME=$HOME/Library/Android/sdk' >> ~/.zshrc
echo 'export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin:$ANDROID_HOME/platform-tools:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

5. Accept Android licenses:
```bash
flutter doctor --android-licenses
# Press 'y' to accept all
```

---

## Step 5 — Verify Setup

```bash
flutter doctor -v
```

All items should show ✓. Fix any issues shown.

---

## Step 6 — Generate Release Keystore

The release keystore for Android is already configured in `build.gradle.kts`.
Generate it once:

```bash
cd "/Users/sayan/Documents/Bakaloo X Shotlin/bakaloo-flutter-app"
bash scripts/generate_keystore.sh
```

---

## Step 7 — Install Project Dependencies

```bash
cd "/Users/sayan/Documents/Bakaloo X Shotlin/bakaloo-flutter-app"

# Flutter packages
flutter pub get

# Generate code (freezed, riverpod, retrofit)
dart run build_runner build --delete-conflicting-outputs

# iOS CocoaPods
cd ios && pod install && cd ..
```

---

## Step 8 — Create & Launch Emulators

### Android Emulator
```bash
bash scripts/setup_emulators.sh
```

### iOS Simulator
```bash
open -a Simulator
# Or via Flutter:
flutter run -d "iPhone 16"
```

---

## Step 9 — Run the App

```bash
# List available devices
flutter devices

# Run on Android emulator
flutter run -d emulator-5554

# Run on iOS simulator
flutter run -d "iPhone 16 Pro"

# Run in release mode (no debugger)
flutter run --release -d emulator-5554
flutter run --release -d "iPhone 16 Pro"
```

---

## Step 10 — Production Builds

```bash
# Full production build script
bash scripts/build_production.sh
```

Or manually:

### Android APK (for direct install / testing)
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (for Google Play Store)
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### iOS Archive (for App Store / TestFlight)
```bash
flutter build ios --release --no-codesign
# Then open Xcode to archive and upload:
open ios/Runner.xcworkspace
# Product → Archive → Distribute App
```

---

## Reuse for Other Projects

All tools installed via Homebrew are **global** on your Mac — they work for any Flutter project:

- `flutter` command works from any directory
- Android SDK at `~/Library/Android/sdk` is shared
- CocoaPods is global
- JDK 17 is global

For a new project: just `flutter pub get` + `cd ios && pod install` and you're ready.

---

## Troubleshooting

### flutter doctor shows Android SDK issues
```bash
flutter config --android-sdk $ANDROID_HOME
```

### CocoaPods issues on Apple Silicon
```bash
sudo arch -x86_64 gem install ffi
arch -x86_64 pod install
```

### Build runner conflicts
```bash
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

### Gradle build fails — out of memory
Already configured in `gradle.properties`:
`org.gradle.jvmargs=-Xmx8G`

---

## Project-Specific Notes

- `.env` file is bundled as an asset — update it before building for different environments
- Firebase config: `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are already in place
- Release keystore: `android/app/bakaloo-release.jks` — **never commit this to git**
- iOS signing: requires Apple Developer account ($99/year) for App Store distribution
