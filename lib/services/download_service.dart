import 'dart:async';
import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
class DownloadSession {
  final StreamSubscription<List<int>> subscription;
  final IOSink output;
  final Completer<void> completer;

  DownloadSession({
    required this.subscription,
    required this.output,
    required this.completer,
  });
}

class DownloadService {
  final YoutubeExplode _yt;
  final Map<String, DownloadSession> _activeSessions = {};

  DownloadService()
      : _yt = YoutubeExplode();

  /// Download a video stream to the specified path
  ///
  /// [stream] - The video/audio stream to download
  /// [savePath] - The full file path where the stream should be saved
  /// [onProgress] - Callback function that receives progress as a percentage (0.0 to 1.0)
  /// [onSpeed] - Optional callback for download speed in bytes per second
  /// [downloadId] - A unique identifier to track and cancel the download
  /// [startByte] - The byte index to resume the download from (ignored in native downloader)
  ///
  /// Returns the file path on successful download
  Future<String> downloadVideo({
    required StreamInfo stream,
    required String savePath,
    required Function(double) onProgress,
    Function(double)? onSpeed,
    required String downloadId,
    required int startByte,
  }) async {
    final file = File(savePath);
    // Ensure parent directory exists
    final parentDir = file.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    final output = file.openWrite(
      mode: FileMode.write,
    );
    final completer = Completer<void>();
    StreamSubscription<List<int>>? subscription;

    try {
      final totalFileSize = stream.size.totalBytes;
      int received = 0;
      int lastReceivedBytes = 0;
      DateTime lastTime = DateTime.now();

      final streamStream = _yt.videos.streamsClient.get(stream);

      subscription = streamStream.listen(
        (data) {
          try {
            output.add(data);
            received += data.length;
            if (totalFileSize > 0) {
              final progress = received / totalFileSize;
              onProgress(progress);

              // Calculate download speed
              if (onSpeed != null) {
                final now = DateTime.now();
                final timeDiff = now.difference(lastTime).inMilliseconds / 1000.0;

                if (timeDiff > 0.5) {
                  final bytesDiff = received - lastReceivedBytes;
                  final speed = bytesDiff / timeDiff;
                  onSpeed(speed);

                  lastReceivedBytes = received;
                  lastTime = now;
                }
              }
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
          }
        },
        onError: (err) {
          if (!completer.isCompleted) {
            completer.completeError(err);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        cancelOnError: true,
      );

      _activeSessions[downloadId] = DownloadSession(
        subscription: subscription,
        output: output,
        completer: completer,
      );

      await completer.future;

      await output.close();
      _activeSessions.remove(downloadId);
      return savePath;
    } catch (e) {
      _activeSessions.remove(downloadId);
      await subscription?.cancel();
      try {
        await output.close();
      } catch (_) {}

      if (e.toString().contains('Download paused')) {
        throw Exception('Download paused');
      }

      // Clean up the file if the download failed or was cancelled
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }

      if (e.toString().contains('cancelled') || e.toString().contains('Cancel')) {
        throw Exception('Download cancelled');
      }
      throw Exception('Download failed: ${e.toString()}');
    }
  }

  /// Pause an ongoing download without deleting the file
  void pauseDownload(String downloadId) {
    final session = _activeSessions.remove(downloadId);
    if (session != null) {
      session.subscription.cancel();
      try {
        session.output.close();
      } catch (_) {}
      if (!session.completer.isCompleted) {
        session.completer.completeError(Exception('Download paused'));
      }
    }
  }

  /// Cancel an ongoing download and delete the temporary file
  void cancelDownload(String downloadId) {
    final session = _activeSessions.remove(downloadId);
    if (session != null) {
      session.subscription.cancel();
      try {
        session.output.close();
      } catch (_) {}
      if (!session.completer.isCompleted) {
        session.completer.completeError(Exception('Download cancelled'));
      }
    }
  }

  /// Check if a download is in progress
  bool isDownloading(String downloadId) {
    return _activeSessions.containsKey(downloadId);
  }

  /// Cancel all ongoing downloads
  void cancelAllDownloads() {
    final keys = _activeSessions.keys.toList();
    for (final key in keys) {
      cancelDownload(key);
    }
    _activeSessions.clear();
  }

  /// Cleanup resources
  void dispose() {
    cancelAllDownloads();
    _yt.close();
  }
}
