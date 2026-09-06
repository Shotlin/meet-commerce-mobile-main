import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _activityTrackedKey = '_activity_tracked';
const String _skipActivityTrackingKey = '_skip_activity_tracking';

class NetworkActivityNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void begin(RequestOptions options) {
    if (options.extra[_skipActivityTrackingKey] == true) {
      return;
    }

    if (options.extra[_activityTrackedKey] == true) {
      return;
    }

    options.extra[_activityTrackedKey] = true;
    state = state + 1;
  }

  void end(RequestOptions options) {
    if (options.extra.remove(_activityTrackedKey) != true) {
      return;
    }

    if (state > 0) {
      state = state - 1;
    }
  }
}

final networkActivityProvider =
    NotifierProvider<NetworkActivityNotifier, int>(NetworkActivityNotifier.new);
