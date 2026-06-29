class ActiveDownload {
  final String id;
  final String videoId;
  final String videoTitle;
  final String thumbnailUrl;
  final String quality;
  final bool needsMerge;
  double progress;
  double speed;
  String status;
  bool isMerging;
  int fileSize;
  String? errorMessage;

  ActiveDownload({
    required this.id,
    required this.videoId,
    required this.videoTitle,
    required this.thumbnailUrl,
    required this.quality,
    required this.needsMerge,
    this.progress = 0.0,
    this.speed = 0.0,
    this.status = 'Preparing...',
    this.isMerging = false,
    this.fileSize = 0,
    this.errorMessage,
  });
}
