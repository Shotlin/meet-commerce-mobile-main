// Bakaloo uses its own app-shell service worker from index.html. Omitting
// Flutter's deprecated serviceWorkerSettings prevents the generated
// unregistering worker from competing for the same scope.
{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load();
