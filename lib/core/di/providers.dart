import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/core/network/dio_client.dart';
import 'package:bakaloo_flutter_app/core/storage/hive_service.dart';
import 'package:bakaloo_flutter_app/core/storage/secure_storage_service.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
SecureStorageService secureStorage(Ref ref) {
  return SecureStorageService();
}

@Riverpod(keepAlive: true)
HiveService hiveService(Ref ref) {
  return const HiveService();
}

@Riverpod(keepAlive: true)
Dio dioClient(Ref ref) {
  return DioClient.create(ref);
}

@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) {
  return ApiClient(ref.watch(dioClientProvider));
}
