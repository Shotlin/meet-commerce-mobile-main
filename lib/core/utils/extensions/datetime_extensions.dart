import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

extension DateTimeExtensions on DateTime {
  String get toRelative {
    return timeago.format(this);
  }

  // The backend always returns UTC ('Z'-suffixed) timestamps — .toLocal()
  // converts to the device's local time zone (IST for Indian users) before
  // formatting. Without it, DateFormat reads the raw UTC hour/minute
  // fields directly and displays them mislabeled as local time.
  String get toIndianDate {
    return DateFormat('d MMM yyyy').format(toLocal());
  }

  String get toIndianDateTime {
    return DateFormat('d MMM yyyy · h:mm a').format(toLocal());
  }

  bool get isExpired => isBefore(DateTime.now());
}
