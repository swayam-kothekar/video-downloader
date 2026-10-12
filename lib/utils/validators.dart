enum PlatformType { youtube, instagram, facebook, twitter, unknown }

class Validators {
  // YouTube URL patterns supporting standard, mobile, shorts, live, embeds, and cookie-less domains
  static final RegExp _youtubeRegex = RegExp(
    r'^(https?://)?(www\.)?(youtube\.com|youtu\.be|m\.youtube\.com|youtube-nocookie\.com)/.+$',
    caseSensitive: false,
  );

  static final RegExp _videoIdRegex = RegExp(
    r'(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?|shorts|live)\/|\S*?[?&]v=)|(?:www\.)?youtu\.be\/|youtube-nocookie\.com\/embed\/)([a-zA-Z0-9_-]{11})',
    caseSensitive: false,
  );

  // Instagram URL patterns supporting reels, posts, tv, mobile and short domains
  static final RegExp _instagramRegex = RegExp(
    r'^(https?://)?(www\.)?(instagram\.com|instagr\.am)\/(reel|reels|p|tv)\/([a-zA-Z0-9_-]+)',
    caseSensitive: false,
  );

  static final RegExp _instagramIdRegex = RegExp(
    r'(?:instagram\.com|instagr\.am)\/(?:reel|reels|p|tv)\/([a-zA-Z0-9_-]+)',
    caseSensitive: false,
  );

  // Facebook URL patterns supporting watch, reels, videos, share, fb.watch, fb.gg, mobile and desktop
  static final RegExp _facebookRegex = RegExp(
    r'^(https?://)?([a-zA-Z0-9-]+\.)?(facebook\.com|fb\.watch|fb\.gg)\/.+$',
    caseSensitive: false,
  );

  static final RegExp _facebookVideoIdRegex = RegExp(
    r'(?:v=|videos\/|reel\/|reels\/|watch\/\?v=|share\/[rv]\/|fb\.watch\/)([0-9a-zA-Z_-]+)',
    caseSensitive: false,
  );

  // Twitter / X URL patterns supporting twitter.com, x.com, mobile domains, statuses and share links
  static final RegExp _twitterRegex = RegExp(
    r'^(https?://)?([a-zA-Z0-9-]+\.)?(twitter\.com|x\.com)\/(?:#!\/)?(\w+)\/status(?:es)?\/(\d+)',
    caseSensitive: false,
  );

  static final RegExp _twitterStatusIdRegex = RegExp(
    r'(?:twitter\.com|x\.com)\/(?:#!\/)?(?:\w+)\/status(?:es)?\/(\d+)',
    caseSensitive: false,
  );

  static final RegExp _twitterUsernameRegex = RegExp(
    r'(?:twitter\.com|x\.com)\/(?:#!\/)?([a-zA-Z0-9_]+)\/status',
    caseSensitive: false,
  );

  /// Validates if a string is a valid URL for any supported platform (YouTube, Instagram, Facebook, Twitter/X)
  static bool isValidUrl(String url) {
    if (url.trim().isEmpty) return false;
    return isValidYouTubeUrl(url) ||
        isValidInstagramUrl(url) ||
        isValidFacebookUrl(url) ||
        isValidTwitterUrl(url);
  }

  /// Determines the platform type for a given URL
  static PlatformType getPlatformType(String url) {
    if (isValidYouTubeUrl(url)) return PlatformType.youtube;
    if (isValidInstagramUrl(url)) return PlatformType.instagram;
    if (isValidFacebookUrl(url)) return PlatformType.facebook;
    if (isValidTwitterUrl(url)) return PlatformType.twitter;
    return PlatformType.unknown;
  }

  /// Human-readable platform name
  static String getPlatformName(String url) {
    switch (getPlatformType(url)) {
      case PlatformType.youtube:
        return 'YouTube';
      case PlatformType.instagram:
        return 'Instagram';
      case PlatformType.facebook:
        return 'Facebook';
      case PlatformType.twitter:
        return 'X (Twitter)';
      case PlatformType.unknown:
        return 'Unknown';
    }
  }

  /// Validates if a string is a valid Instagram URL
  static bool isValidInstagramUrl(String url) {
    if (url.trim().isEmpty) return false;
    final normalized = _normalizeUrl(url);
    return _instagramRegex.hasMatch(normalized) && extractInstagramId(normalized) != null;
  }

  /// Extracts Instagram shortcode (e.g. reel or post ID)
  static String? extractInstagramId(String url) {
    if (url.trim().isEmpty) return null;
    final normalized = _normalizeUrl(url);
    final match = _instagramIdRegex.firstMatch(normalized);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }

  /// Validates if a string is a valid Facebook URL
  static bool isValidFacebookUrl(String url) {
    if (url.trim().isEmpty) return false;
    final normalized = _normalizeUrl(url);
    return _facebookRegex.hasMatch(normalized);
  }

  /// Extracts Facebook video or reel identifier
  static String? extractFacebookId(String url) {
    if (url.trim().isEmpty) return null;
    final normalized = _normalizeUrl(url);
    final match = _facebookVideoIdRegex.firstMatch(normalized);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }

  /// Validates if a string is a valid Twitter or X status URL
  static bool isValidTwitterUrl(String url) {
    if (url.trim().isEmpty) return false;
    final normalized = _normalizeUrl(url);
    return _twitterRegex.hasMatch(normalized) && extractTwitterId(normalized) != null;
  }

  /// Extracts Twitter / X status identifier
  static String? extractTwitterId(String url) {
    if (url.trim().isEmpty) return null;
    final normalized = _normalizeUrl(url);
    final match = _twitterStatusIdRegex.firstMatch(normalized);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }

  /// Extracts Twitter / X username (or null if generic /i/)
  static String? extractTwitterUsername(String url) {
    if (url.trim().isEmpty) return null;
    final normalized = _normalizeUrl(url);
    final match = _twitterUsernameRegex.firstMatch(normalized);
    if (match != null && match.groupCount >= 1) {
      final user = match.group(1);
      if (user != null && user.toLowerCase() != 'i') {
        return user;
      }
    }
    return null;
  }

  /// Validates if a string is a valid YouTube URL
  static bool isValidYouTubeUrl(String url) {
    if (url.trim().isEmpty) return false;
    final normalized = _normalizeUrl(url);
    return _youtubeRegex.hasMatch(normalized) && extractVideoId(normalized) != null;
  }

  /// Extracts video ID from various YouTube URL formats
  static String? extractVideoId(String url) {
    if (url.trim().isEmpty) return null;
    final normalized = _normalizeUrl(url);
    final match = _videoIdRegex.firstMatch(normalized);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }

  static String _normalizeUrl(String url) {
    String normalized = url.trim();
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }
    try {
      normalized = Uri.decodeFull(normalized);
    } catch (_) {}
    return normalized;
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
