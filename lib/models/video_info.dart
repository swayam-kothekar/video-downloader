class VideoInfo {
  final String id;
  final String title;
  final String author;
  final String channelId;
  final String thumbnailUrl;
  final Duration duration;
  final int viewCount;
  final String description;
  final DateTime uploadDate;

  VideoInfo({
    required this.id,
    required this.title,
    required this.author,
    required this.channelId,
    required this.thumbnailUrl,
    required this.duration,
    required this.viewCount,
    required this.description,
    required this.uploadDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'channelId': channelId,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration.inSeconds,
      'viewCount': viewCount,
      'description': description,
      'uploadDate': uploadDate.toIso8601String(),
    };
  }

  factory VideoInfo.fromJson(Map<String, dynamic> json) {
    return VideoInfo(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      channelId: json['channelId'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      duration: Duration(seconds: json['duration'] as int),
      viewCount: json['viewCount'] as int,
      description: json['description'] as String,
      uploadDate: DateTime.parse(json['uploadDate'] as String),
    );
  }
}
