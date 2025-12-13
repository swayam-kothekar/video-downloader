import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class DownloadService {
  final Dio _dio;
  final Map<String, CancelToken> _cancelTokens = {};

  DownloadService() : _dio = Dio();

  /// Download a video stream to the specified path
  ///
  /// [stream] - The video/audio stream to download
  /// [savePath] - The full file path where the video should be saved
  /// [onProgress] - Callback function that receives progress as a percentage (0.0 to 1.0)
  /// [onSpeed] - Optional callback for download speed in bytes per second
  ///
  /// Returns the file path on successful download
  Future<String> downloadVideo({
    required StreamInfo stream,
    required String savePath,
    required Function(double) onProgress,
    Function(double)? onSpeed,
    String? downloadId,
  }) async {
    try {
      final id = downloadId ?? DateTime.now().millisecondsSinceEpoch.toString();
      final cancelToken = CancelToken();
      _cancelTokens[id] = cancelToken;

      int lastReceivedBytes = 0;
      DateTime lastTime = DateTime.now();

      await _dio.download(
        stream.url.toString(),
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress(progress);

            // Calculate download speed
            if (onSpeed != null) {
              final now = DateTime.now();
              final timeDiff = now.difference(lastTime).inMilliseconds / 1000;

              if (timeDiff > 0.5) {
                // Update speed every 500ms
                final bytesDiff = received - lastReceivedBytes;
                final speed = bytesDiff / timeDiff;
                onSpeed(speed);

                lastReceivedBytes = received;
                lastTime = now;
              }
            }
          }
        },
      );

      _cancelTokens.remove(id);
      return savePath;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        throw Exception('Download cancelled');
      }
      throw Exception('Download failed: ${e.toString()}');
    }
  }

  /// Cancel an ongoing download
  void cancelDownload(String downloadId) {
    final cancelToken = _cancelTokens[downloadId];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('Download cancelled by user');
      _cancelTokens.remove(downloadId);
    }
  }

  /// Check if a download is in progress
  bool isDownloading(String downloadId) {
    return _cancelTokens.containsKey(downloadId);
  }

  /// Cancel all ongoing downloads
  void cancelAllDownloads() {
    for (final cancelToken in _cancelTokens.values) {
      if (!cancelToken.isCancelled) {
        cancelToken.cancel('All downloads cancelled');
      }
    }
    _cancelTokens.clear();
  }

  /// Cleanup resources
  void dispose() {
    cancelAllDownloads();
    _dio.close();
  }
}
