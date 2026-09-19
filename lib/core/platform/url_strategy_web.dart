import 'package:flutter_web_plugins/url_strategy.dart' as url_strategy;

/// Use clean browser paths (`/home`) instead of hash URLs (`/#/home`).
void configureUrlStrategy() {
  url_strategy.usePathUrlStrategy();
}
