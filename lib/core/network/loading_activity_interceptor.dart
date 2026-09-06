import 'package:dio/dio.dart';

import 'package:bakaloo_flutter_app/core/network/network_activity_provider.dart';

class LoadingActivityInterceptor extends Interceptor {
  LoadingActivityInterceptor(this._notifier);

  final NetworkActivityNotifier _notifier;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    _notifier.begin(options);
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _notifier.end(response.requestOptions);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _notifier.end(err.requestOptions);
    handler.next(err);
  }
}
