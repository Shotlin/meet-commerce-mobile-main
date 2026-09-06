import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bakaloo_flutter_app/core/di/providers.dart';
import 'package:bakaloo_flutter_app/features/checkout/domain/entities/delivery_slot_entity.dart';

part 'delivery_slot_provider.g.dart';

@riverpod
Future<List<DeliverySlotDayEntity>> deliverySlots(Ref ref) async {
  final dio = ref.watch(dioClientProvider);
  final response = await dio.get<dynamic>('/delivery/slots');
  final body = response.data as Map<String, dynamic>?;
  if (body == null || body['success'] != true) {
    throw Exception('Failed to load delivery slots');
  }
  final data = body['data'] as Map<String, dynamic>?;
  if (data == null) return [];
  final rawDays = data['days'] as List<dynamic>? ?? [];
  return rawDays
      .map((d) => DeliverySlotDayEntity.fromJson(Map<String, dynamic>.from(d as Map)))
      .toList();
}
