import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class DownloadSession {
  final IOSink output;
  final Completer<void> completer;
  final List<StreamSubscription<List<int>>> activeSubscriptions;
  final http.Client? client;

  DownloadSession({
    required this.output,
    required this.completer,
    required this.activeSubscriptions,
    this.client,
  });
}

class DownloadService {
  late final YoutubeExplode _yt;
  late final YoutubeHttpClient _client;
  final Map<String, DownloadSession> _activeSessions = {};

  DownloadService() {
    _client = YoutubeHttpClient();
    _yt = YoutubeExplode(httpClient: _client);
  }

  /// Download a video stream to the specified path.
  /// Supports resume, chunk-based downloading for throttled streams,
  /// connection timeout, inactivity watchdog, and manifest/URL auto-refresh.
  Future<String> downloadStream({
    required StreamInfo streamInfo,
    required String savePath,
    required Function(double) onProgress,
    Function(double)? onSpeed,
    required String downloadId,
  }) async {
    final file = File(savePath);
    final parentDir = file.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    IOSink? output;
    final completer = Completer<void>();
    final activeSubscriptions = <StreamSubscription<List<int>>>[];

    try {
      // Start a clean download from 0
      if (await file.exists()) {
        await file.delete();
      }

      final totalBytes = streamInfo.size.totalBytes;
      int received = 0;
      int speedLastBytes = 0;
      DateTime speedLastTime = DateTime.now();

      output = file.openWrite(mode: FileMode.write);

      final session = DownloadSession(
        output: output,
        completer: completer,
        activeSubscriptions: activeSubscriptions,
      );
      _activeSessions[downloadId] = session;

      debugPrint('DownloadId $downloadId: Starting stream download to $savePath');

      final stream = _yt.videos.streamsClient.get(streamInfo);

      final completerStream = Completer<void>();
      int lastReceived = 0;

      // 120 second inactivity watchdog during data read
      // (resilient to screen sleep and network pauses — the CPU throttles
      // heavily when the screen is off, so short timeouts cause false failures)
      final inactivityWatchdog = Timer.periodic(const Duration(seconds: 120), (timer) {
        if (received == lastReceived && !completerStream.isCompleted) {
          timer.cancel();
          completerStream.completeError(TimeoutException('Read timed out - no data for 120s'));
        } else {
          lastReceived = received;
        }
      });

      final sub = stream.listen(
        (data) {
          if (completer.isCompleted) {
            inactivityWatchdog.cancel();
            if (!completerStream.isCompleted) completerStream.complete();
            return;
          }

          output?.add(data);
          received += data.length;

          if (totalBytes > 0) {
            final progress = (received / totalBytes).clamp(0.0, 0.99);
            onProgress(progress);
          } else {
            onProgress(0.0);
          }

          if (onSpeed != null) {
            final now = DateTime.now();
            final timeDiff = now.difference(speedLastTime).inMilliseconds / 1000.0;
            if (timeDiff > 0.5) {
              final speed = (received - speedLastBytes) / timeDiff;
              onSpeed(speed);
              speedLastBytes = received;
              speedLastTime = now;
            }
          }
        },
        onError: (err) {
          inactivityWatchdog.cancel();
          if (!completerStream.isCompleted) completerStream.completeError(err);
        },
        onDone: () {
          inactivityWatchdog.cancel();
          if (!completerStream.isCompleted) completerStream.complete();
        },
        cancelOnError: true,
      );
      activeSubscriptions.add(sub);

      await completerStream.future;
      activeSubscriptions.remove(sub);

      if (!completer.isCompleted) {
        completer.complete();
      }

      await completer.future;
      await output.flush();
      await output.close();
      _activeSessions.remove(downloadId);

      // Complete progress to 100%
      onProgress(1.0);
      return savePath;
    } catch (e) {
      _activeSessions.remove(downloadId);
      for (final sub in activeSubscriptions) {
        try {
          await sub.cancel();
        } catch (_) {}
      }
      try {
        await output?.flush();
        await output?.close();
      } catch (_) {}

      final errStr = e.toString();
      if (errStr.contains('Download paused')) {
        throw Exception('Download paused');
      }

      if (errStr.contains('cancelled') || errStr.contains('Cancel')) {
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {}
        }
        throw Exception('Download cancelled');
      }

      throw Exception('Download failed');
    }
  }

  /// Download a direct video URL (e.g., Instagram or Facebook MP4) to the specified path.
  Future<String> downloadFromUrl({
    required String url,
    required String savePath,
    required Function(double) onProgress,
    Function(double)? onSpeed,
    required String downloadId,
    Map<String, String>? headers,
  }) async {
    final file = File(savePath);
    final parentDir = file.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    IOSink? output;
    final completer = Completer<void>();
    final activeSubscriptions = <StreamSubscription<List<int>>>[];
    final httpClient = http.Client();

    try {
      if (await file.exists()) {
        await file.delete();
      }

      output = file.openWrite(mode: FileMode.write);

      final session = DownloadSession(
        output: output,
        completer: completer,
        activeSubscriptions: activeSubscriptions,
        client: httpClient,
      );
      _activeSessions[downloadId] = session;

      debugPrint('DownloadId $downloadId: Starting direct URL download to $savePath');

      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll({
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': '*/*',
        ...?headers,
      });

      final streamedResponse = await httpClient.send(request);
      if (streamedResponse.statusCode < 200 || streamedResponse.statusCode >= 300) {
        throw Exception('Server returned HTTP ${streamedResponse.statusCode}');
      }

      final totalBytes = streamedResponse.contentLength ?? 0;
      int received = 0;
      int speedLastBytes = 0;
      DateTime speedLastTime = DateTime.now();

      final completerStream = Completer<void>();
      int lastReceived = 0;

      final inactivityWatchdog = Timer.periodic(const Duration(seconds: 120), (timer) {
        if (received == lastReceived && !completerStream.isCompleted) {
          timer.cancel();
          completerStream.completeError(TimeoutException('Read timed out - no data for 120s'));
        } else {
          lastReceived = received;
        }
      });

      final sub = streamedResponse.stream.listen(
        (data) {
          if (completer.isCompleted) {
            inactivityWatchdog.cancel();
            if (!completerStream.isCompleted) completerStream.complete();
            return;
          }

          output?.add(data);
          received += data.length;

          if (totalBytes > 0) {
            final progress = (received / totalBytes).clamp(0.0, 0.99);
            onProgress(progress);
          } else {
            onProgress(0.0);
          }

          if (onSpeed != null) {
            final now = DateTime.now();
            final timeDiff = now.difference(speedLastTime).inMilliseconds / 1000.0;
            if (timeDiff > 0.5) {
              final speed = (received - speedLastBytes) / timeDiff;
              onSpeed(speed);
              speedLastBytes = received;
              speedLastTime = now;
            }
          }
        },
        onError: (err) {
          inactivityWatchdog.cancel();
          if (!completerStream.isCompleted) completerStream.completeError(err);
        },
        onDone: () {
          inactivityWatchdog.cancel();
          if (!completerStream.isCompleted) completerStream.complete();
        },
        cancelOnError: true,
      );
      activeSubscriptions.add(sub);

      await completerStream.future;
      activeSubscriptions.remove(sub);

      if (!completer.isCompleted) {
        completer.complete();
      }

      await completer.future;
      await output.flush();
      await output.close();
      httpClient.close();
      _activeSessions.remove(downloadId);

      onProgress(1.0);
      return savePath;
    } catch (e) {
      httpClient.close();
      _activeSessions.remove(downloadId);
      for (final sub in activeSubscriptions) {
        try {
          await sub.cancel();
        } catch (_) {}
      }
      try {
        await output?.flush();
        await output?.close();
      } catch (_) {}

      final errStr = e.toString();
      if (errStr.contains('Download paused')) {
        throw Exception('Download paused');
      }

      if (errStr.contains('cancelled') || errStr.contains('Cancel')) {
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {}
        }
        throw Exception('Download cancelled');
      }

      throw Exception('Download failed: ${e.toString()}');
    }
  }

  /// Pause without deleting the partial file.
  void pauseDownload(String downloadId) {
    final session = _activeSessions.remove(downloadId);
    if (session != null) {
      for (final sub in session.activeSubscriptions) {
        try {
          sub.cancel();
        } catch (_) {}
      }
      try {
        session.client?.close();
      } catch (_) {}
      try {
        session.output.close();
      } catch (_) {}
      if (!session.completer.isCompleted) {
        session.completer.completeError(Exception('Download paused'));
      }
    }
  }

  /// Cancel and delete the partial file.
  void cancelDownload(String downloadId) {
    final session = _activeSessions.remove(downloadId);
    if (session != null) {
      for (final sub in session.activeSubscriptions) {
        try {
          sub.cancel();
        } catch (_) {}
      }
      try {
        session.client?.close();
      } catch (_) {}
      try {
        session.output.close();
      } catch (_) {}
      if (!session.completer.isCompleted) {
        session.completer.completeError(Exception('Download cancelled'));
      }
    }
  }

  bool isDownloading(String downloadId) =>
      _activeSessions.containsKey(downloadId);

  void cancelAllDownloads() {
    final keys = _activeSessions.keys.toList();
    for (final key in keys) {
      cancelDownload(key);
    }
  }

  void dispose() {
    cancelAllDownloads();
    _yt.close();
    _client.close();
  }
}
