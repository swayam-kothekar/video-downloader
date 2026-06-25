import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/download_log.dart';

class StorageService {
  static const platform = MethodChannel('com.example.video_downloader/storage');

  /// Get a temporary directory for downloads (app-specific, no permissions needed)
  Future<String> getTempDownloadDirectory() async {
    if (Platform.isAndroid) {
      // Use app-specific external storage (no permissions required)
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        final tempDir = Directory('${directory.path}/temp_downloads');
        if (!await tempDir.exists()) {
          await tempDir.create(recursive: true);
        }
        return tempDir.path;
      }
    }

    // Fallback to application documents directory
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// Save file to public Downloads folder using MediaStore (no permissions needed on Android 10+)
  Future<String> saveToPublicDownloads(String filePath, String fileName) async {
    if (Platform.isAndroid) {
      try {
        final String? result = await platform.invokeMethod('saveToDownloads', {
          'filePath': filePath,
          'displayName': fileName,
        });

        if (result != null) {
          return result; // Returns content URI
        } else {
          throw Exception('Failed to save file to Downloads');
        }
      } on PlatformException catch (e) {
        throw Exception('Failed to save to Downloads: ${e.message}');
      }
    }

    // For non-Android platforms, just return the original path
    return filePath;
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

  /// Check if a file exists
  Future<bool> fileExists(String filePath) async {
    try {
      return await File(filePath).exists();
    } catch (e) {
      return false;
    }
  }

  /// Delete a temporary file
  Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore deletion errors
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
