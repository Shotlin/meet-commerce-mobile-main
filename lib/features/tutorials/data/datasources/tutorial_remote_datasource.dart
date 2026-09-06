import 'package:bakaloo_flutter_app/core/network/api_client.dart';
import 'package:bakaloo_flutter_app/features/tutorials/domain/entities/tutorial_video_entity.dart';

class TutorialRemoteDataSource {
  TutorialRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<TutorialVideoEntity>> getTutorials() async {
    final response = await _apiClient.getTutorials();
    final data = response.data ?? const <dynamic>[];
    return data
        .whereType<Map>()
        .map(
          (Map item) =>
              TutorialVideoEntity.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }
}
