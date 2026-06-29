import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/video_info.dart';
import '../models/download_log.dart';
import '../models/active_download.dart';
import '../services/youtube_service.dart';
import '../services/download_service.dart';
import '../services/storage_service.dart';
import '../services/foreground_service_helper.dart';
import '../utils/validators.dart';
import 'package:wakelock_plus/wakelock_plus.dart';


enum VideoState { idle, loading, loaded, error }

class VideoProvider extends ChangeNotifier {
  final YouTubeService _youtubeService;
  final DownloadService _downloadService;
  final StorageService _storageService;

  VideoProvider(
    this._youtubeService,
    this._downloadService,
    this._storageService,
  ) {
    _loadDownloadLogs();
  }

  // Search and metadata state
  VideoState _state = VideoState.idle;
  VideoInfo? _currentVideo;
  Map<String, StreamInfo> _availableStreams = {};
  String _selectedQuality = '360p';
  String? _errorMessage;
  
  // Parallel downloads state
  final Map<String, ActiveDownload> _activeDownloads = {};
  final Map<String, StreamSubscription<ConnectivityResult>> _connectivitySubscriptions = {};
  List<DownloadLog> _downloadLogs = [];
  
  static const int _maxRetries = 8;

  // Throttle UI notifications during downloads to avoid flooding the main
  // isolate with hundreds of rebuilds per second (which causes the blank
  // screen freeze when returning from background).
  Timer? _notifyThrottle;
  bool _notifyScheduled = false;
  DateTime _lastSideEffectTime = DateTime(0);

  // Getters
  VideoState get state => _state;
  VideoInfo? get currentVideo => _currentVideo;
  Map<String, StreamInfo> get availableStreams => _availableStreams;
  List<String> get availableQualities {
    final qualities = _availableStreams.keys.toList();
    qualities.sort((a, b) {
      if (a == 'Audio Only') return 1;
      if (b == 'Audio Only') return -1;
      final aNum = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final bNum = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return bNum.compareTo(aNum);
    });
    return qualities;
  }
  String get selectedQuality => _selectedQuality;
  String? get errorMessage => _errorMessage;
  StorageService get storageService => _storageService;
  List<DownloadLog> get downloadLogs => _downloadLogs;
  Map<String, ActiveDownload> get activeDownloads => _activeDownloads;

  /// Check if the currently selected video is downloading
  bool get isCurrentlySelectedVideoDownloading => false;

  /// Check if any download is active
  bool get hasActiveDownloads => _activeDownloads.isNotEmpty;

  /// Get the number of running (non-paused) downloads
  int get activeDownloadsCount {
    return _activeDownloads.values.where((d) => d.status != 'Paused').length;
  }

  /// Fetch video information from URL
  Future<void> fetchVideoInfo(String url, {String? defaultQuality}) async {
    try {
      _state = VideoState.loading;
      _errorMessage = null;
      notifyListeners();

      // Normalize URL (ensure scheme)
      String normalizedUrl = url.trim();
      if (!normalizedUrl.startsWith('http://') && !normalizedUrl.startsWith('https://')) {
        normalizedUrl = 'https://$normalizedUrl';
      }

      final videoId = Validators.extractVideoId(normalizedUrl);
      if (videoId == null) {
        throw Exception('Invalid YouTube URL');
      }

      final results = await Future.wait([
        _youtubeService.getVideoInfo(normalizedUrl),
        _youtubeService.getAvailableStreams(videoId),
      ]);

      _currentVideo = results[0] as VideoInfo;
      _availableStreams = results[1] as Map<String, StreamInfo>;

      // Quality fixed to 360p (muxed stream — no merge needed)
      // Falls back to the first available quality if 360p is not present
      if (_availableStreams.containsKey('360p')) {
        _selectedQuality = '360p';
      } else if (_availableStreams.isNotEmpty) {
        _selectedQuality = _availableStreams.keys.first;
      }

      _state = VideoState.loaded;
      notifyListeners();
    } catch (e) {
      _state = VideoState.error;
      _errorMessage = _parseExceptionMessage(e);
      _currentVideo = null;
      _availableStreams = {};
      notifyListeners();
    }
  }

  /// Download the current video (async background execution)
  Future<void> downloadVideo({required bool wifiOnly, required bool subtitleDownload}) async {
    debugPrint('VideoProvider: downloadVideo() called');

    if (_currentVideo == null ||
        !_availableStreams.containsKey(_selectedQuality)) {
      debugPrint('VideoProvider: No video or quality not available');
      _errorMessage = 'No video selected or quality not available';
      _state = VideoState.error;
      notifyListeners();
      return;
    }

    final video = _currentVideo!;
    final quality = _selectedQuality;
    final selectedStream = _availableStreams[quality];
    final needsMerge = selectedStream != null &&
        selectedStream is! MuxedStreamInfo &&
        quality != 'Audio Only';
    
    // Make the download ID unique by appending a timestamp to allow simultaneous downloads of the same video quality
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final downloadId = '${video.id}_${quality.replaceAll(' ', '_')}_$timestamp';

    final activeDownload = ActiveDownload(
      id: downloadId,
      videoId: video.id,
      videoTitle: video.title,
      thumbnailUrl: video.thumbnailUrl,
      quality: quality,
      needsMerge: needsMerge,
      status: 'Preparing download...',
    );

    _activeDownloads[downloadId] = activeDownload;
    notifyListeners();


    // Start background download flow asynchronously
    _runBackgroundDownload(
      activeDownload: activeDownload,
      video: video,
      quality: quality,
      needsMerge: needsMerge,
      wifiOnly: wifiOnly,
      subtitleDownload: subtitleDownload,
    );
  }

  /// Runs the download process in the background, updating activeDownload state
  Future<void> _runBackgroundDownload({
    required ActiveDownload activeDownload,
    required VideoInfo? video,
    required String quality,
    required bool needsMerge,
    required bool wifiOnly,
    required bool subtitleDownload,
  }) async {
    final downloadId = activeDownload.id;

    // Start the foreground service so Android keeps the process alive
    // while the screen is off or the app is in the background.
    await _startForegroundServiceIfNeeded();

    VideoInfo? currentVideo = video;
    Map<String, StreamInfo> streams = _availableStreams;

    try {
      if (currentVideo == null || streams.isEmpty) {
        currentVideo = await _youtubeService.getVideoInfo(activeDownload.videoId);
        streams = await _youtubeService.getAvailableStreams(activeDownload.videoId);
      }
    } catch (e, stack) {
      debugPrint('Error preparing background download: $e\n$stack');
      activeDownload.errorMessage = 'Download failed';
      activeDownload.status = 'Error';
      _notifyNow();
      return;
    }
    StreamSubscription<ConnectivityResult>? connectivitySubscription;

    if (wifiOnly) {
      final result = await Connectivity().checkConnectivity();
      final isMobile = result == ConnectivityResult.mobile;
      if (isMobile) {
        activeDownload.errorMessage = 'Download failed';
        activeDownload.status = 'Error';
        _notifyNow();
        
        // Log failure
        final log = DownloadLog(
          videoTitle: currentVideo.title,
          quality: quality,
          downloadDate: DateTime.now(),
          isSuccess: false,
          errorMessage: 'Download failed',
        );
        _downloadLogs.insert(0, log);
        await _storageService.saveDownloadLogs(_downloadLogs);
        
        // Remove from active downloads after a short delay
        Future.delayed(const Duration(seconds: 5), () {
          _activeDownloads.remove(downloadId);
          notifyListeners();
        });
        return;
      }

      // Listen to connectivity changes during download
      connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
        if (result == ConnectivityResult.mobile && _activeDownloads.containsKey(downloadId)) {
          _pauseDownloadServiceCall(downloadId, needsMerge);
          activeDownload.errorMessage = 'Download paused: Cellular network detected (Wi-Fi Only Mode)';
          activeDownload.status = 'Paused';
          _notifyNow();
        }
      });
      _connectivitySubscriptions[downloadId] = connectivitySubscription;
    }

    int retryCount = 0;
    while (retryCount <= _maxRetries) {
      try {
        if (retryCount > 0) {
          activeDownload.status = 'Refreshing download link...';
          notifyListeners();
          try {
            currentVideo = await _youtubeService.getVideoInfo(activeDownload.videoId);
            streams = await _youtubeService.getAvailableStreams(activeDownload.videoId);
          } catch (err) {
            debugPrint('Failed to refresh stream links on retry: $err');
            throw Exception('Failed to refresh stream links: $err');
          }
        }

        activeDownload.status = 'Preparing download...';
        activeDownload.speed = 0.0;
        activeDownload.isMerging = false;
        notifyListeners();

        final downloadDir = await _storageService.getTempDownloadDirectory();

        // 1. Resolve stream infos
        final videoStream = streams[quality];
        final audioStream = streams['Audio Only'];

        if (videoStream == null && quality != 'Audio Only') {
          throw Exception('Stream not available for quality: $quality');
        }

        // 2. Calculate estimated file size
        int estimatedSize = 0;
        try {
          if (quality == 'Audio Only') {
            estimatedSize = audioStream?.size.totalBytes ?? 0;
          } else if (videoStream is MuxedStreamInfo) {
            estimatedSize = videoStream.size.totalBytes;
          } else {
            final videoSize = videoStream?.size.totalBytes ?? 0;
            final audioSize = audioStream?.size.totalBytes ?? 0;
            estimatedSize = videoSize + audioSize;
          }
        } catch (_) {}

        activeDownload.fileSize = estimatedSize;

        // 3. Generate filename and temp paths
        final extension = quality == 'Audio Only' ? 'm4a' : 'mp4';
        final fileName = _storageService.generateFileName(
          currentVideo!.title,
          quality,
          extension,
        );
        final fileNameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
        final tempFilePath = '$downloadDir/${fileNameWithoutExt}_$downloadId.$extension';

        activeDownload.status = 'Downloading...';
        notifyListeners();

        // When subtitles are enabled, reserve the last 10% of the progress bar
        // for the subtitle fetch + save phase so the user doesn't see it stuck at 100%.
        final double mediaProgressCap = subtitleDownload ? 0.90 : 1.0;

        if (quality == 'Audio Only') {
          // Audio-only stream download
          await _downloadService.downloadStream(
            streamInfo: audioStream!,
            savePath: tempFilePath,
            downloadId: downloadId,
            onProgress: (p) {
              activeDownload.progress = (p * mediaProgressCap).clamp(0.0, mediaProgressCap);
              notifyListeners();
            },
            onSpeed: (s) {
              activeDownload.speed = s;
              notifyListeners();
            },
          );
        } else if (videoStream is MuxedStreamInfo) {
          // Muxed stream — already has audio+video combined
          await _downloadService.downloadStream(
            streamInfo: videoStream,
            savePath: tempFilePath,
            downloadId: downloadId,
            onProgress: (p) {
              activeDownload.progress = (p * mediaProgressCap).clamp(0.0, mediaProgressCap);
              notifyListeners();
            },
            onSpeed: (s) {
              activeDownload.speed = s;
              notifyListeners();
            },
          );
        } else {
          // Video-only stream: download video first, then audio, then merge
          final tempVideoPath = '$downloadDir/${fileNameWithoutExt}_${downloadId}_temp_video.mp4';
          final tempAudioPath = '$downloadDir/${fileNameWithoutExt}_${downloadId}_temp_audio.m4a';

          final videoSize = videoStream?.size.totalBytes ?? 0;
          final audioSize = audioStream?.size.totalBytes ?? 0;
          final totalSize = videoSize + audioSize;

          // Phase 1: Download video stream
          final videoRatio = totalSize > 0 ? videoSize / totalSize : 0.8;

          await _downloadService.downloadStream(
            streamInfo: videoStream!,
            savePath: tempVideoPath,
            downloadId: '${downloadId}_video',
            onProgress: (p) {
              activeDownload.progress = (p * videoRatio * mediaProgressCap).clamp(0.0, videoRatio * mediaProgressCap);
              notifyListeners();
            },
            onSpeed: (s) {
              activeDownload.speed = s;
              notifyListeners();
            },
          );

          // Phase 2: Download audio stream
          final audioRatio = 1.0 - videoRatio;
          activeDownload.speed = 0.0;

          final audioBase = videoRatio * mediaProgressCap;
          final audioCap = mediaProgressCap * 0.95; // leave room for merge

          await _downloadService.downloadStream(
            streamInfo: audioStream!,
            savePath: tempAudioPath,
            downloadId: '${downloadId}_audio',
            onProgress: (p) {
              activeDownload.progress = (audioBase + p * audioRatio * mediaProgressCap).clamp(audioBase, audioCap);
              notifyListeners();
            },
            onSpeed: (s) {
              activeDownload.speed = s;
              notifyListeners();
            },
          );

          // Phase 3: Merge video + audio with ffmpeg
          activeDownload.speed = 0.0;
          activeDownload.isMerging = true;

          final result = await Process.run('ffmpeg', [
            '-y',
            '-i', tempVideoPath,
            '-i', tempAudioPath,
            '-c:v', 'copy',
            '-c:a', 'aac',
            tempFilePath,
          ]);

          if (result.exitCode != 0) {
            throw Exception('FFmpeg merge failed: ${result.stderr}');
          }

          activeDownload.isMerging = false;
          activeDownload.progress = mediaProgressCap * 0.99;

          await _storageService.deleteFile(tempVideoPath);
          await _storageService.deleteFile(tempAudioPath);
        }

        await _storageService.saveToPublicDownloads(tempFilePath, fileName);

        if (subtitleDownload) {
          activeDownload.progress = 0.92;
          activeDownload.speed = 0.0;
          notifyListeners();

          await _downloadSubtitles(currentVideo.id, tempFilePath, fileName);

          activeDownload.progress = 0.97;
          notifyListeners();
        }

        await _storageService.deleteFile(tempFilePath);

        activeDownload.status = 'Complete';
        activeDownload.progress = 1.0;
        _notifyNow();

        // Clean up on success
        _cancelConnectivitySubscription(downloadId);
        Future.delayed(const Duration(seconds: 2), () async {
          final log = DownloadLog(
            videoTitle: currentVideo!.title,
            quality: quality,
            downloadDate: DateTime.now(),
            isSuccess: true,
          );
          _downloadLogs.insert(0, log);
          await _storageService.saveDownloadLogs(_downloadLogs);
          _activeDownloads.remove(downloadId);
          _stopForegroundServiceIfIdle();
          _notifyNow();
        });
        break;
      } catch (e, stack) {
        debugPrint('Error during background download (attempt $retryCount): $e\n$stack');
        if (e.toString().contains('Download paused')) {
          _cancelConnectivitySubscription(downloadId);
          activeDownload.status = 'Paused';
          activeDownload.speed = 0.0;
          _notifyNow();
          return;
        }

        if (e.toString().contains('Download cancelled')) {
          _cancelConnectivitySubscription(downloadId);
          _activeDownloads.remove(downloadId);
          _notifyNow();
          return;
        }

        if (retryCount < _maxRetries) {
          retryCount++;
          activeDownload.status = 'Retrying connection... ($retryCount/$_maxRetries)';
          _notifyNow();
          await Future.delayed(Duration(seconds: 2 + (retryCount * 2)));
          continue;
        }

        // Max retries exceeded
        _cancelConnectivitySubscription(downloadId);
        final log = DownloadLog(
          videoTitle: currentVideo?.title ?? activeDownload.videoTitle,
          quality: quality,
          downloadDate: DateTime.now(),
          isSuccess: false,
          errorMessage: 'Download failed',
        );
        _downloadLogs.insert(0, log);
        await _storageService.saveDownloadLogs(_downloadLogs);

        activeDownload.errorMessage = 'Download failed';
        activeDownload.status = 'Error';
        _notifyNow();

        // Keep error visible for 8 seconds, then remove
        Future.delayed(const Duration(seconds: 8), () {
          _activeDownloads.remove(downloadId);
          _stopForegroundServiceIfIdle();
          _notifyNow();
        });
        break;
      }
    }
  }

  void _cancelDownloadServiceCall(String downloadId, bool needsMerge) {
    if (needsMerge) {
      _downloadService.cancelDownload('${downloadId}_video');
      _downloadService.cancelDownload('${downloadId}_audio');
    } else {
      _downloadService.cancelDownload(downloadId);
    }
  }

  void _pauseDownloadServiceCall(String downloadId, bool needsMerge) {
    if (needsMerge) {
      _downloadService.pauseDownload('${downloadId}_video');
      _downloadService.pauseDownload('${downloadId}_audio');
    } else {
      _downloadService.pauseDownload(downloadId);
    }
  }

  void _cancelConnectivitySubscription(String downloadId) {
    _connectivitySubscriptions[downloadId]?.cancel();
    _connectivitySubscriptions.remove(downloadId);
  }

  /// Delete any temporary download files on disk for a given download
  Future<void> _deleteTempFiles(ActiveDownload activeDownload) async {
    try {
      final downloadDir = await _storageService.getTempDownloadDirectory();
      final downloadId = activeDownload.id;
      final title = activeDownload.videoTitle;
      final quality = activeDownload.quality;

      if (activeDownload.needsMerge) {
        final baseName = _storageService.generateFileName(title, quality, 'mp4');
        final baseNameWithoutExt = baseName.substring(0, baseName.lastIndexOf('.'));
        final tempVideoPath = '$downloadDir/${baseNameWithoutExt}_${downloadId}_temp_video.mp4';
        final tempAudioPath = '$downloadDir/${baseNameWithoutExt}_${downloadId}_temp_audio.m4a';
        final tempMergedPath = '$downloadDir/${baseNameWithoutExt}_$downloadId.mp4';

        await _storageService.deleteFile(tempVideoPath);
        await _storageService.deleteFile(tempAudioPath);
        await _storageService.deleteFile(tempMergedPath);
      } else {
        final extension = quality == 'Audio Only' ? 'm4a' : 'mp4';
        final fileName = _storageService.generateFileName(title, quality, extension);
        final fileNameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
        final tempFilePath = '$downloadDir/${fileNameWithoutExt}_$downloadId.$extension';

        await _storageService.deleteFile(tempFilePath);
      }
    } catch (e) {
      debugPrint('Error deleting temp files: $e');
    }
  }

  /// Cancel an ongoing active download
  void cancelDownload(String downloadId) {
    final activeDownload = _activeDownloads[downloadId];
    if (activeDownload == null) return;
    
    _cancelDownloadServiceCall(downloadId, activeDownload.needsMerge);
    _cancelConnectivitySubscription(downloadId);
    _deleteTempFiles(activeDownload);
    _activeDownloads.remove(downloadId);
    _stopForegroundServiceIfIdle();
    notifyListeners();
  }

  /// Pause an ongoing active download
  void pauseDownload(String downloadId) {
    final activeDownload = _activeDownloads[downloadId];
    if (activeDownload == null) return;

    _pauseDownloadServiceCall(downloadId, activeDownload.needsMerge);
    _cancelConnectivitySubscription(downloadId);
    activeDownload.status = 'Paused';
    activeDownload.speed = 0.0;
    _stopForegroundServiceIfIdle();
    _notifyNow();
  }

  /// Resume a paused download
  Future<void> resumeDownload(String downloadId, {required bool wifiOnly, required bool subtitleDownload}) async {
    final activeDownload = _activeDownloads[downloadId];
    if (activeDownload == null || activeDownload.status != 'Paused') return;

    activeDownload.status = 'Preparing download...';
    activeDownload.errorMessage = null;
    notifyListeners();

    // Start background download flow asynchronously
    _runBackgroundDownload(
      activeDownload: activeDownload,
      video: null,
      quality: activeDownload.quality,
      needsMerge: activeDownload.needsMerge,
      wifiOnly: wifiOnly,
      subtitleDownload: subtitleDownload,
    );
  }

  /// Reset search/loading state
  void reset() {
    _state = VideoState.idle;
    _currentVideo = null;
    _availableStreams = {};
    _selectedQuality = '360p';
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear the current error message
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Clear all download logs
  Future<void> clearDownloadLogs() async {
    _downloadLogs.clear();
    await _storageService.saveDownloadLogs(_downloadLogs);
    notifyListeners();
  }

  /// Delete a single download log
  Future<void> deleteDownloadLog(DownloadLog log) async {
    _downloadLogs.remove(log);
    await _storageService.saveDownloadLogs(_downloadLogs);
    notifyListeners();
  }

  /// Load download logs from storage
  Future<void> _loadDownloadLogs() async {
    try {
      _downloadLogs = await _storageService.loadDownloadLogs();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load download logs: $e');
    }
  }

  String _parseExceptionMessage(dynamic e) {
    final errorStr = e.toString();
    
    if (errorStr.contains('RequestLimitExceededException') || errorStr.contains('rate limiting') || errorStr.contains('429')) {
      return 'Something went wrong. Please try again later.';
    } else if (errorStr.contains('SocketException') || errorStr.contains('NetworkInfo') || errorStr.contains('Failed host lookup') || errorStr.contains('Network unreachable')) {
      return 'No internet connection. Please check your network and try again.';
    } else if (errorStr.contains('VideoUnplayableException') || errorStr.contains('private') || errorStr.contains('requires sign-in') || errorStr.contains('Login required')) {
      return 'This video is private or restricted, and cannot be downloaded without authentication.';
    } else if (errorStr.contains('VideoUnavailableException') || errorStr.contains('not found') || errorStr.contains('does not exist')) {
      return 'The video could not be found. Please check that the URL is correct.';
    } else if (errorStr.contains('VideoRequirePurchaseException') || errorStr.contains('rental') || errorStr.contains('requires purchase')) {
      return 'This video is paid or requires purchase/renting, and cannot be downloaded.';
    }
    
    // Clean up generic Exception prefix if present
    if (errorStr.startsWith('Exception: ')) {
      return errorStr.substring(11);
    }
    return errorStr;
  }

  Future<void> _downloadSubtitles(String videoId, String tempFilePath, String fileName) async {
    try {
      debugPrint('VideoProvider: Fetching subtitle closed captions...');
      final manifest = await _youtubeService.getClosedCaptionManifest(videoId);
      if (manifest.tracks.isNotEmpty) {
        // Try English first (manual, then auto-generated), then first available
        ClosedCaptionTrackInfo? trackInfo;
        try {
          // First try manually-authored English captions
          final englishTracks = manifest.getByLanguage('en');
          if (englishTracks.isNotEmpty) {
            trackInfo = englishTracks.first;
          } else {
            // Most videos only have auto-generated captions
            final autoEnglishTracks = manifest.getByLanguage('en', autoGenerated: true);
            if (autoEnglishTracks.isNotEmpty) {
              trackInfo = autoEnglishTracks.first;
            }
          }
        } catch (_) {}
        trackInfo ??= manifest.tracks.first;

        final track = await _youtubeService.getClosedCaptionTrack(trackInfo);
        
        // Format to SRT
        final srtContent = _convertTrackToSrt(track);
        
        // Write to temp file
        final baseNameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
        final srtFileName = '$baseNameWithoutExt.srt';
        
        final tempVideoFile = File(tempFilePath);
        final tempVideoBaseName = tempVideoFile.path.split('/').last;
        final tempVideoBaseNameWithoutExt = tempVideoBaseName.substring(0, tempVideoBaseName.lastIndexOf('.'));
        final tempSrtPath = '${tempVideoFile.parent.path}/$tempVideoBaseNameWithoutExt.srt';
        
        final srtFile = File(tempSrtPath);
        await srtFile.writeAsString(srtContent);
        
        // Save to public Downloads
        await _storageService.saveToPublicDownloads(tempSrtPath, srtFileName);
        
        // Clean up temp
        await _storageService.deleteFile(tempSrtPath);
        debugPrint('VideoProvider: Subtitles saved successfully');
      } else {
        debugPrint('VideoProvider: No subtitles available for this video');
      }
    } catch (e) {
      debugPrint('VideoProvider: Error downloading subtitles: $e');
    }
  }

  String _convertTrackToSrt(ClosedCaptionTrack track) {
    final buffer = StringBuffer();
    for (int i = 0; i < track.captions.length; i++) {
      final caption = track.captions[i];
      final start = caption.offset;
      final end = caption.offset + caption.duration;
      
      buffer.writeln('${i + 1}');
      buffer.writeln('${_formatDurationToSrt(start)} --> ${_formatDurationToSrt(end)}');
      buffer.writeln(caption.text);
      buffer.writeln();
    }
    return buffer.toString();
  }

  String _formatDurationToSrt(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    final milliseconds = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$hours:$minutes:$seconds,$milliseconds';
  }



  /// Start foreground service if not already running.
  Future<void> _startForegroundServiceIfNeeded() async {
    try {
      final runningCount = activeDownloadsCount;
      await ForegroundServiceHelper.start(
        'Downloading...',
        '$runningCount download${runningCount == 1 ? '' : 's'} in progress',
      );
    } catch (e) {
      debugPrint('Failed to start foreground service: $e');
    }
  }

  /// Stop foreground service when no active (non-paused, non-error, non-complete) downloads remain.
  void _stopForegroundServiceIfIdle() {
    final hasActiveRunningTasks = _activeDownloads.values.any(
      (d) => d.status != 'Paused' && d.status != 'Error' && d.status != 'Complete',
    );
    if (!hasActiveRunningTasks) {
      ForegroundServiceHelper.stop();
    }
  }

  @override
  void notifyListeners() {
    // When downloads are active, throttle UI rebuilds to ~4 per second.
    // This prevents hundreds of rebuilds/sec from data-chunk callbacks and
    // eliminates the freeze/blank screen when returning from background.
    if (_activeDownloads.isNotEmpty && _hasRunningDownloads()) {
      // Throttle heavy platform-channel side-effects to ~once per second
      final now = DateTime.now();
      if (now.difference(_lastSideEffectTime).inMilliseconds > 1000) {
        _lastSideEffectTime = now;
        _updateWakelock();
        _updateForegroundNotification();
      }

      if (!_notifyScheduled) {
        _notifyScheduled = true;
        _notifyThrottle?.cancel();
        _notifyThrottle = Timer(const Duration(milliseconds: 250), () {
          _notifyScheduled = false;
          super.notifyListeners();
        });
      }
    } else {
      // No active downloads — notify immediately for instant UI feedback
      _updateWakelock();
      _updateForegroundNotification();
      super.notifyListeners();
    }
  }

  /// Force an immediate notification, bypassing the throttle.
  /// Use for critical state transitions (Complete, Error, Paused).
  void _notifyNow() {
    _notifyThrottle?.cancel();
    _notifyScheduled = false;
    _updateWakelock();
    _updateForegroundNotification();
    super.notifyListeners();
  }

  bool _hasRunningDownloads() {
    return _activeDownloads.values.any(
      (d) => d.status != 'Paused' && d.status != 'Error' && d.status != 'Complete',
    );
  }

  void _updateForegroundNotification() {
    try {
      final hasActiveRunningTasks = _activeDownloads.values.any(
        (d) => d.status != 'Paused' && d.status != 'Error' && d.status != 'Complete',
      );
      if (hasActiveRunningTasks) {
        final runningCount = _activeDownloads.values
            .where((d) => d.status != 'Paused' && d.status != 'Error' && d.status != 'Complete')
            .length;
        ForegroundServiceHelper.update(
          'Downloading...',
          '$runningCount download${runningCount == 1 ? '' : 's'} in progress',
        );
      }
    } catch (_) {}
  }

  void _updateWakelock() {
    try {
      final hasActiveRunningTasks = _activeDownloads.values.any(
        (d) => d.status != 'Paused' && d.status != 'Error' && d.status != 'Complete',
      );
      if (hasActiveRunningTasks) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _notifyThrottle?.cancel();
    try {
      WakelockPlus.disable();
    } catch (_) {}
    for (final sub in _connectivitySubscriptions.values) {
      sub.cancel();
    }
    _connectivitySubscriptions.clear();
    _youtubeService.dispose();
    _downloadService.dispose();
    super.dispose();
  }
}
