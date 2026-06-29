import 'package:dio/dio.dart';
import '../utils/constants.dart';

class AppUpdateInfo {
  final String latestVersion;
  final String releaseUrl;
  final String releaseNotes;

  AppUpdateInfo({
    required this.latestVersion,
    required this.releaseUrl,
    required this.releaseNotes,
  });
}

class UpdateService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent': 'video_downloader_app',
      'Accept': 'application/vnd.github.v3+json',
    },
  ));

  /// Check if a new version is available on GitHub
  Future<AppUpdateInfo?> checkForUpdates() async {
    try {
      final response = await _dio.get(
        'https://api.github.com/repos/swayam-kothekar/video-downloader/releases/latest',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final latestVersion = data['tag_name'] as String? ?? '';
        final releaseUrl = data['html_url'] as String? ?? '';
        final releaseNotes = data['body'] as String? ?? 'No release notes provided.';
        
        if (latestVersion.isNotEmpty && isNewerVersion(AppConstants.appVersion, latestVersion)) {
          return AppUpdateInfo(
            latestVersion: latestVersion,
            releaseUrl: releaseUrl,
            releaseNotes: releaseNotes,
          );
        }
      }
    } catch (e) {
      // Fail silently in case of network errors or rate limiting
      return null;
    }
    return null;
  }

  /// Compare semantic version numbers (e.g. 1.1.0 vs v1.2.0)
  static bool isNewerVersion(String current, String latest) {
    try {
      final currentClean = current.toLowerCase().replaceAll('v', '').trim();
      final latestClean = latest.toLowerCase().replaceAll('v', '').trim();

      final currentParts = currentClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final latestParts = latestClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLength = currentParts.length > latestParts.length ? currentParts.length : latestParts.length;

      for (int i = 0; i < maxLength; i++) {
        final currentPart = i < currentParts.length ? currentParts[i] : 0;
        final latestPart = i < latestParts.length ? latestParts[i] : 0;

        if (latestPart > currentPart) return true;
        if (latestPart < currentPart) return false;
      }
    } catch (e) {
      // In case of parsing error, return simple inequality
      return current.trim() != latest.trim();
    }
    return false;
  }
}
