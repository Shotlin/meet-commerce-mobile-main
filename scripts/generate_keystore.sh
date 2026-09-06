#!/usr/bin/env bash
# ============================================================
# Bakaloo — Android Release Keystore Generator
# Run this ONCE to create the release signing keystore.
# The keystore file is gitignored — keep it safe!
# ============================================================

set -euo pipefail

KEYSTORE_DIR="$(cd "$(dirname "$0")/.." && pwd)/android/app"
KEYSTORE_FILE="$KEYSTORE_DIR/bakaloo-release.jks"

if [ -f "$KEYSTORE_FILE" ]; then
  echo "✅ Keystore already exists at: $KEYSTORE_FILE"
  echo "   Delete it first if you want to regenerate."
  exit 0
fi

echo "🔑 Generating Android release keystore..."
echo "   Location: $KEYSTORE_FILE"
echo ""

keytool -genkeypair \
  -v \
  -keystore "$KEYSTORE_FILE" \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias bakaloo \
  -storepass bakaloo123 \
  -keypass bakaloo123 \
  -dname "CN=Bakaloo, OU=Mobile, O=Bakaloo, L=India, ST=India, C=IN"

echo ""
echo "✅ Keystore generated successfully!"
echo "   File: $KEYSTORE_FILE"
echo ""
echo "⚠️  IMPORTANT: This file is gitignored. Back it up securely."
echo "   If you lose it, you cannot update the app on Google Play."
