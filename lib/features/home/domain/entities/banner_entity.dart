import 'package:freezed_annotation/freezed_annotation.dart';

part 'banner_entity.freezed.dart';

@freezed
abstract class BannerEntity with _$BannerEntity {
  const factory BannerEntity({
    required String id,
    required String imageUrl,
    required String linkType,
    required int sortOrder,
    String? title,
    String? subtitle,
    String? linkValue,
  }) = _BannerEntity;
}
