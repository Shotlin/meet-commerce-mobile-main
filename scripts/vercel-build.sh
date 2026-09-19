#!/usr/bin/env bash
# Builds the Flutter web/PWA bundle for Vercel. All values below are public
# browser configuration; secrets must be configured only on the backend.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.41.9}"
SDK_CACHE_ROOT="${VERCEL_CACHE_DIR:-/tmp}/bakaloo-flutter-sdk"
SDK_DIR="${SDK_CACHE_ROOT}/flutter-${FLUTTER_VERSION}"

if [ ! -x "${SDK_DIR}/bin/flutter" ]; then
  mkdir -p "${SDK_CACHE_ROOT}"
  rm -rf "${SDK_DIR}" "${SDK_CACHE_ROOT}/flutter"
  curl --fail --location --silent --show-error \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar -xJ -C "${SDK_CACHE_ROOT}"
  mv "${SDK_CACHE_ROOT}/flutter" "${SDK_DIR}"
fi

export PATH="${SDK_DIR}/bin:${PATH}"
flutter config --no-analytics
flutter pub get
flutter build web --release \
  --dart-define=BASE_URL="${BASE_URL:-https://api.bakaloo.in/api/v1}" \
  --dart-define=SOCKET_URL="${SOCKET_URL:-https://api.bakaloo.in}"
