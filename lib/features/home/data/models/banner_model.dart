import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:bakaloo_flutter_app/core/constants/api_constants.dart';
import 'package:bakaloo_flutter_app/features/home/domain/entities/banner_entity.dart';

part 'banner_model.freezed.dart';
part 'banner_model.g.dart';

@freezed
abstract class BannerModel with _$BannerModel {
  const BannerModel._();

  const factory BannerModel({
    required String id,
    @JsonKey(name: 'image_url') required String imageUrl,
    @JsonKey(name: 'link_type') required String linkType,
    String? title,
    String? subtitle,
    @JsonKey(name: 'link_value') String? linkValue,
    @JsonKey(name: 'sort_order') @Default(0) int sortOrder,
  }) = _BannerModel;

  factory BannerModel.fromJson(Map<String, dynamic> json) =>
      _$BannerModelFromJson(json);

  BannerEntity toEntity() {
    return BannerEntity(
      id: id,
      title: title,
      subtitle: subtitle,
      imageUrl: ApiConstants.resolveMediaUrl(imageUrl) ?? imageUrl,
      linkType: linkType,
      linkValue: linkValue,
      sortOrder: sortOrder,
    );
  }
}
