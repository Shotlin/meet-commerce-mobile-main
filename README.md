# bakaloo_flutter_app

> Bakaloo — Customer Mobile App

A new Flutter project.

## Web / PWA

Use the repository-managed Flutter SDK and pass only public browser configuration at build time:

```powershell
.\.fvm\flutter_sdk\bin\flutter.bat run -d chrome --dart-define=BASE_URL=https://api.bakaloo.in/api/v1 --dart-define=SOCKET_URL=https://api.bakaloo.in --dart-define=WEB_BASE_URL=https://YOUR_WEB_ORIGIN

# Optional: enable only after the dashboard campaign artwork has passed the Bakaloo brand review.
# --dart-define=ALLOW_REMOTE_MARKETING_ASSETS=true

.\.fvm\flutter_sdk\bin\flutter.bat build web --release --dart-define=BASE_URL=https://api.bakaloo.in/api/v1 --dart-define=SOCKET_URL=https://api.bakaloo.in --dart-define=WEB_BASE_URL=https://YOUR_WEB_ORIGIN
```

Release-readiness, implementation, and verification notes are in `docs/BAKALOO_WEB_*.md`. Do not expose API secrets, payment secrets, Firebase server credentials, or production service-account keys through web defines or checked-in files.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
