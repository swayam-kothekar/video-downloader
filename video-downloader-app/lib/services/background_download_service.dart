import 'dart:isolate';
import 'dart:ui';
import 'package:flutter_downloader/flutter_downloader.dart';

@pragma('vm:entry-point')
class BackgroundDownloadService {
  static const String _portName = 'downloader_send_port';

  final ReceivePort _port = ReceivePort();
  Function(String taskId, int progress)? onProgressCallback;
  Function(String taskId)? onCompleteCallback;
  Function(String taskId, String error)? onErrorCallback;

  BackgroundDownloadService() {
    _bindBackgroundIsolate();
  }

  void _bindBackgroundIsolate() {
    final isSuccess = IsolateNameServer.registerPortWithName(
      _port.sendPort,
      _portName,
    );

    if (!isSuccess) {
      _unbindBackgroundIsolate();
      _bindBackgroundIsolate();
      return;
    }

    _port.listen((dynamic data) {
      final String taskId = data[0];
      final int status = data[1];
      final int progress = data[2];

      if (status == DownloadTaskStatus.running.index) {
        onProgressCallback?.call(taskId, progress);
      } else if (status == DownloadTaskStatus.complete.index) {
        onCompleteCallback?.call(taskId);
      } else if (status == DownloadTaskStatus.failed.index) {
        onErrorCallback?.call(taskId, 'Download failed');
      }
    });

    FlutterDownloader.registerCallback(downloadCallback);
  }

  void _unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping(_portName);
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName(_portName);
    send?.send([id, status, progress]);
  }

  /// Start a download and return the task ID
  Future<String?> startDownload({
    required String url,
    required String savePath,
    required String fileName,
  }) async {
    try {
      print('BackgroundDownloadService: Starting download');
      print('URL: $url');
      print('Save path: $savePath');
      print('File name: $fileName');

      final taskId = await FlutterDownloader.enqueue(
        url: url,
        savedDir: savePath,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: false,
        saveInPublicStorage:
            false, // Using scoped storage with MediaStore instead
        requiresStorageNotLow: false,
      );

      print('BackgroundDownloadService: Download queued with task ID: $taskId');
      return taskId;
    } catch (e, stackTrace) {
      print('BackgroundDownloadService: Error starting download: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Cancel a download
  Future<void> cancelDownload(String taskId) async {
    await FlutterDownloader.cancel(taskId: taskId);
  }

  /// Remove a download task
  Future<void> removeTask(String taskId) async {
    await FlutterDownloader.remove(taskId: taskId);
  }

  void dispose() {
    _unbindBackgroundIsolate();
    _port.close();
  }
}
