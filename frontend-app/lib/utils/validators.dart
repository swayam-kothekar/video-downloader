class Validators {
  // YouTube URL patterns
  static final RegExp _youtubeRegex = RegExp(
    r'^(https?://)?(www\.)?(youtube\.com|youtu\.be|m\.youtube\.com)/.+$',
    caseSensitive: false,
  );

  static final RegExp _videoIdRegex = RegExp(
    r'(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
    caseSensitive: false,
  );

  /// Validates if a string is a valid YouTube URL
  static bool isValidYouTubeUrl(String url) {
    if (url.isEmpty) return false;
    return _youtubeRegex.hasMatch(url) && extractVideoId(url) != null;
  }

  /// Extracts video ID from various YouTube URL formats
  static String? extractVideoId(String url) {
    if (url.isEmpty) return null;

    final match = _videoIdRegex.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }

    return null;
  }

  /// Formats duration as HH:MM:SS or MM:SS
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  /// Converts bytes to human-readable file size (KB, MB, GB)
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// Formats numbers with K/M/B suffixes for large numbers (e.g., view counts)
  static String formatNumber(int number) {
    if (number < 1000) {
      return number.toString();
    } else if (number < 1000000) {
      return '${(number / 1000).toStringAsFixed(number % 1000 == 0 ? 0 : 1)}K';
    } else if (number < 1000000000) {
      return '${(number / 1000000).toStringAsFixed(number % 1000000 == 0 ? 0 : 1)}M';
    } else {
      return '${(number / 1000000000).toStringAsFixed(number % 1000000000 == 0 ? 0 : 1)}B';
    }
  }
}
