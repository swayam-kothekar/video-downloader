class DownloadLog {
  final String videoTitle;
  final String quality;
  final DateTime downloadDate;
  final bool isSuccess;
  final String? errorMessage;

  DownloadLog({
    required this.videoTitle,
    required this.quality,
    required this.downloadDate,
    required this.isSuccess,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'videoTitle': videoTitle,
      'quality': quality,
      'downloadDate': downloadDate.toIso8601String(),
      'isSuccess': isSuccess,
      'errorMessage': errorMessage,
    };
  }

  factory DownloadLog.fromJson(Map<String, dynamic> json) {
    return DownloadLog(
      videoTitle: json['videoTitle'] as String,
      quality: json['quality'] as String,
      downloadDate: DateTime.parse(json['downloadDate'] as String),
      isSuccess: json['isSuccess'] as bool,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}
