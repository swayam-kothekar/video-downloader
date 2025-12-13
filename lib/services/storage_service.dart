import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/download_log.dart';

class StorageService {
  /// Get current permission status
  Future<PermissionStatus> getPermissionStatus() async {
    if (Platform.isAndroid) {
      // Check storage permission status
      return await Permission.storage.status;
    }
    // For iOS and other platforms, assume granted
    return PermissionStatus.granted;
  }

  /// Request storage permissions
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), we need different permissions
      if (await Permission.photos.isGranted ||
          await Permission.videos.isGranted) {
        return true;
      }

      // For older Android versions
      if (await Permission.storage.isGranted) {
        return true;
      }

      // Request necessary permissions
      final statuses = await [
        Permission.storage,
        Permission.manageExternalStorage,
      ].request();

      return statuses[Permission.storage]?.isGranted == true ||
          statuses[Permission.manageExternalStorage]?.isGranted == true;
    }

    // For iOS and other platforms
    return true;
  }

  /// Request notification permission (required for download notifications on Android 13+)
  Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      if (await Permission.notification.isGranted) {
        return true;
      }
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true; // For non-Android platforms
  }

  /// Get the download directory path
  Future<String> getDownloadDirectory() async {
    if (Platform.isAndroid) {
      // Return the public Downloads directory directly
      // For Android, we'll use /storage/emulated/0/Download
      final directory = Directory('/storage/emulated/0/Download');

      // Check if directory exists, if not try to create it
      if (!await directory.exists()) {
        try {
          await directory.create(recursive: true);
        } catch (e) {
          // If we can't access Downloads, fallback to external storage
          final fallbackDir = await getExternalStorageDirectory();
          if (fallbackDir != null) {
            return fallbackDir.path;
          }
          // Last resort: throw exception
          throw Exception('Unable to access storage directories');
        }
      }

      return directory.path;
    }

    // Fallback to application documents directory for non-Android platforms
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// Generate a safe filename from video title
  String generateFileName(String title, String quality, String extension) {
    // Remove invalid filename characters
    final safeTitle = title
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Limit filename length
    final maxLength = 100;
    final truncatedTitle = safeTitle.length > maxLength
        ? safeTitle.substring(0, maxLength)
        : safeTitle;

    return '${truncatedTitle}_$quality.$extension';
  }

  /// Check available storage space
  Future<int> getAvailableSpace() async {
    try {
      final directory = await getDownloadDirectory();
      final diskSpace = await Directory(directory).stat();
      // Note: This is a simplified version. For accurate space calculation,
      // you might want to use platform-specific code
      return diskSpace.size;
    } catch (e) {
      return 0;
    }
  }

  /// Check if a file exists
  Future<bool> fileExists(String filePath) async {
    try {
      return await File(filePath).exists();
    } catch (e) {
      return false;
    }
  }

  /// Save download logs (keeps only last 5)
  Future<void> saveDownloadLogs(List<DownloadLog> logs) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/download_logs.json');

      // Keep only last 5 logs
      final logsToSave = logs.length > 5 ? logs.sublist(0, 5) : logs;

      final jsonList = logsToSave.map((log) => log.toJson()).toList();
      final jsonString = jsonEncode(jsonList);

      await file.writeAsString(jsonString);
    } catch (e) {
      // Ignore errors
    }
  }

  /// Load download logs
  Future<List<DownloadLog>> loadDownloadLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/download_logs.json');

      if (!await file.exists()) {
        return [];
      }

      final jsonString = await file.readAsString();
      final jsonList = jsonDecode(jsonString) as List;

      return jsonList
          .map((json) => DownloadLog.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }
}
