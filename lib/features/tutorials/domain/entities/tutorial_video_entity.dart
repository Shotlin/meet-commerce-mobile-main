class TutorialVideoEntity {
  const TutorialVideoEntity({
    required this.id,
    required this.title,
    required this.videoId,
    required this.videoUrl,
    this.language,
  });

  final String id;
  final String title;
  final String videoId;
  final String videoUrl;
  final String? language;

  factory TutorialVideoEntity.fromJson(Map<String, dynamic> json) {
    return TutorialVideoEntity(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      videoId: (json['video_id'] ?? json['videoId'] ?? '').toString(),
      videoUrl: (json['video_url'] ?? json['videoUrl'] ?? '').toString(),
      language: (json['language'] as String?)?.trim().isNotEmpty == true
          ? json['language'] as String
          : null,
    );
  }

  String get thumbnailUrl => 'https://img.youtube.com/vi/$videoId/mqdefault.jpg';

  // A YouTube Short is filmed/exported vertical (9:16) — the admin-pasted
  // /shorts/ URL is the only signal we have for this, since video_id alone
  // doesn't carry orientation. Driving the player's aspect ratio off this
  // avoids forcing a vertical video into a 16:9 box, which is what caused
  // it to render as a small letterboxed sliver surrounded by black.
  bool get isShort => videoUrl.contains('/shorts/');
}
