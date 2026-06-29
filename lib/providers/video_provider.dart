import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/video_info.dart';
import '../models/download_log.dart';
import '../models/active_download.dart';
import '../services/youtube_service.dart';
import '../services/download_service.dart';
import '../services/storage_service.dart';
import '../utils/validators.dart';

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
  
  static const int _maxRetries = 3;

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

      // Set quality based on default quality setting, falling back intelligently
      if (_availableStreams.isNotEmpty) {
        if (defaultQuality != null && _availableStreams.containsKey(defaultQuality)) {
          _selectedQuality = defaultQuality;
        } else {
          // Filter out 'Audio Only' and sort by resolution
          final videoQualities = _availableStreams.keys
              .where((key) => key != 'Audio Only')
              .toList();

          if (videoQualities.isNotEmpty) {
            videoQualities.sort((a, b) {
              final aNum = int.tryParse(a.replaceAll('p', '')) ?? 0;
              final bNum = int.tryParse(b.replaceAll('p', '')) ?? 0;
              return bNum.compareTo(aNum); // Descending order
            });
            
            if (defaultQuality != null) {
              final defaultNum = int.tryParse(defaultQuality.replaceAll('p', '')) ?? 0;
              String? bestMatch;
              for (final q in videoQualities) {
                final qNum = int.tryParse(q.replaceAll('p', '')) ?? 0;
                if (qNum <= defaultNum) {
                  bestMatch = q;
                  break;
                }
              }
              _selectedQuality = bestMatch ?? videoQualities.first;
            } else {
              _selectedQuality = videoQualities.first;
            }
          } else {
            // If only audio is available, select it
            _selectedQuality = _availableStreams.keys.first;
          }
        }
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

  /// Select a quality for download
  void selectQuality(String quality) {
    if (_availableStreams.containsKey(quality)) {
      _selectedQuality = quality;
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
    final stream = _availableStreams[quality]!;
    final needsMerge = quality != 'Audio Only' && stream is VideoOnlyStreamInfo;
    
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
      stream: stream,
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
    required StreamInfo? stream,
    required bool needsMerge,
    required bool wifiOnly,
    required bool subtitleDownload,
  }) async {
    final downloadId = activeDownload.id;

    VideoInfo? currentVideo = video;
    StreamInfo? currentStream = stream;
    Map<String, StreamInfo> streams = _availableStreams;

    try {
      if (currentVideo == null || currentStream == null) {
        currentVideo = await _youtubeService.getVideoInfo(activeDownload.videoId);
        streams = await _youtubeService.getAvailableStreams(activeDownload.videoId);
        currentStream = streams[quality]!;
      }
    } catch (e) {
      activeDownload.errorMessage = 'Download failed';
      activeDownload.status = 'Error';
      notifyListeners();
      return;
    }
    StreamSubscription<ConnectivityResult>? connectivitySubscription;

    if (wifiOnly) {
      final result = await Connectivity().checkConnectivity();
      final isMobile = result == ConnectivityResult.mobile;
      if (isMobile) {
        activeDownload.errorMessage = 'Download failed';
        activeDownload.status = 'Error';
        notifyListeners();
        
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
          notifyListeners();
        }
      });
      _connectivitySubscriptions[downloadId] = connectivitySubscription;
    }

    int retryCount = 0;
    while (retryCount <= _maxRetries) {
      try {
        activeDownload.status = 'Preparing download...';
        activeDownload.speed = 0.0;
        activeDownload.isMerging = false;
        notifyListeners();

        final downloadDir = await _storageService.getTempDownloadDirectory();

        if (needsMerge) {
          final videoStream = currentStream;
          final audioStream = streams['Audio Only']!;

          final videoSize = videoStream.size.totalBytes;
          final audioSize = audioStream.size.totalBytes;
          activeDownload.fileSize = videoSize + audioSize;

          final baseName = _storageService.generateFileName(
            currentVideo.title,
            quality,
            'mp4',
          );
          final baseNameWithoutExt = baseName.substring(0, baseName.lastIndexOf('.'));
          // Use downloadId to avoid collision with other concurrent downloads of the same video + quality
          final tempVideoPath = '$downloadDir/${baseNameWithoutExt}_${downloadId}_temp_video.mp4';
          final tempAudioPath = '$downloadDir/${baseNameWithoutExt}_${downloadId}_temp_audio.m4a';

          final tempVideoFile = File(tempVideoPath);
          final tempAudioFile = File(tempAudioPath);
          final int startVideoByte = tempVideoFile.existsSync() ? tempVideoFile.lengthSync() : 0;
          final int startAudioByte = tempAudioFile.existsSync() ? tempAudioFile.lengthSync() : 0;

          double videoProgress = videoSize > 0 ? startVideoByte / videoSize : 0.0;
          double audioProgress = audioSize > 0 ? startAudioByte / audioSize : 0.0;

          if (startVideoByte < videoSize) {
            activeDownload.status = 'Downloading video...';
            notifyListeners();

            await _downloadService.downloadVideo(
              stream: videoStream,
              savePath: tempVideoPath,
              downloadId: '${downloadId}_video',
              startByte: startVideoByte,
              onProgress: (p) {
                videoProgress = p;
                final totalBytes = videoSize + audioSize;
                activeDownload.progress = totalBytes > 0 
                    ? ((videoProgress * videoSize) + (audioProgress * audioSize)) / totalBytes
                    : (videoProgress + audioProgress) / 2;
                notifyListeners();
              },
              onSpeed: (s) {
                activeDownload.speed = s;
                notifyListeners();
              },
            );
            videoProgress = 1.0;
          } else {
            videoProgress = 1.0;
          }

          if (startAudioByte < audioSize) {
            activeDownload.status = 'Downloading audio...';
            notifyListeners();

            await _downloadService.downloadVideo(
              stream: audioStream,
              savePath: tempAudioPath,
              downloadId: '${downloadId}_audio',
              startByte: startAudioByte,
              onProgress: (p) {
                audioProgress = p;
                final totalBytes = videoSize + audioSize;
                activeDownload.progress = totalBytes > 0 
                    ? ((videoProgress * videoSize) + (audioProgress * audioSize)) / totalBytes
                    : (videoProgress + audioProgress) / 2;
                notifyListeners();
              },
              onSpeed: (s) {
                activeDownload.speed = s;
                notifyListeners();
              },
            );
            audioProgress = 1.0;
          } else {
            audioProgress = 1.0;
          }

          // Merge and finalize
          activeDownload.status = 'Merging audio & video...';
          activeDownload.isMerging = true;
          notifyListeners();

          final tempMergedPath = '$downloadDir/${baseNameWithoutExt}_$downloadId.mp4';
          final session = await FFmpegKit.execute('-y -i "$tempVideoPath" -i "$tempAudioPath" -c:v copy -c:a copy "$tempMergedPath"');
          var returnCode = await session.getReturnCode();

          if (!ReturnCode.isSuccess(returnCode)) {
            final fallbackSession = await FFmpegKit.execute('-y -i "$tempVideoPath" -i "$tempAudioPath" -c:v copy -c:a aac "$tempMergedPath"');
            returnCode = await fallbackSession.getReturnCode();
          }

          if (ReturnCode.isSuccess(returnCode)) {
            activeDownload.status = 'Saving to Downloads...';
            notifyListeners();

            await _storageService.saveToPublicDownloads(tempMergedPath, baseName);

            if (subtitleDownload) {
              await _downloadSubtitles(currentVideo.id, tempMergedPath, baseName);
            }

            await _storageService.deleteFile(tempVideoPath);
            await _storageService.deleteFile(tempAudioPath);
            await _storageService.deleteFile(tempMergedPath);

            final log = DownloadLog(
              videoTitle: currentVideo.title,
              quality: quality,
              downloadDate: DateTime.now(),
              isSuccess: true,
            );
            _downloadLogs.insert(0, log);
            await _storageService.saveDownloadLogs(_downloadLogs);

            activeDownload.status = 'Complete';
            activeDownload.progress = 1.0;
            activeDownload.isMerging = false;
            notifyListeners();
          } else {
            throw Exception('FFmpeg merge process failed');
          }
        } else {
          // Single file download
          final fileSize = currentStream.size.totalBytes;
          activeDownload.fileSize = fileSize;

          String extension = quality == 'Audio Only' ? 'm4a' : 'mp4';
          final fileName = _storageService.generateFileName(
            currentVideo.title,
            quality,
            extension,
          );
          final fileNameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
          // Use downloadId to avoid collision with other concurrent downloads of the same video + quality
          final tempFilePath = '$downloadDir/${fileNameWithoutExt}_$downloadId.$extension';

          final tempFile = File(tempFilePath);
          final int startByte = tempFile.existsSync() ? tempFile.lengthSync() : 0;

          if (startByte < fileSize) {
            activeDownload.status = 'Downloading...';
            notifyListeners();

            await _downloadService.downloadVideo(
              stream: currentStream,
              savePath: tempFilePath,
              downloadId: downloadId,
              startByte: startByte,
              onProgress: (p) {
                activeDownload.progress = p;
                notifyListeners();
              },
              onSpeed: (s) {
                activeDownload.speed = s;
                notifyListeners();
              },
            );
          }

          activeDownload.status = 'Saving to Downloads...';
          notifyListeners();

          await _storageService.saveToPublicDownloads(tempFilePath, fileName);

          if (subtitleDownload) {
            await _downloadSubtitles(currentVideo.id, tempFilePath, fileName);
          }

          await _storageService.deleteFile(tempFilePath);

          final log = DownloadLog(
            videoTitle: currentVideo.title,
            quality: quality,
            downloadDate: DateTime.now(),
            isSuccess: true,
          );
          _downloadLogs.insert(0, log);
          await _storageService.saveDownloadLogs(_downloadLogs);

          activeDownload.status = 'Complete';
          activeDownload.progress = 1.0;
          notifyListeners();
        }

        // Clean up on success
        _cancelConnectivitySubscription(downloadId);
        Future.delayed(const Duration(seconds: 4), () {
          _activeDownloads.remove(downloadId);
          notifyListeners();
        });
        break;
      } catch (e) {
        if (e.toString().contains('Download paused')) {
          _cancelConnectivitySubscription(downloadId);
          activeDownload.status = 'Paused';
          activeDownload.speed = 0.0;
          notifyListeners();
          return;
        }

        if (e.toString().contains('Download cancelled')) {
          _cancelConnectivitySubscription(downloadId);
          _activeDownloads.remove(downloadId);
          notifyListeners();
          return;
        }

        if (retryCount < _maxRetries) {
          retryCount++;
          activeDownload.status = 'Retrying... (Attempt $retryCount/$_maxRetries)';
          notifyListeners();
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }

        // Max retries exceeded
        _cancelConnectivitySubscription(downloadId);
        final log = DownloadLog(
          videoTitle: currentVideo.title,
          quality: quality,
          downloadDate: DateTime.now(),
          isSuccess: false,
          errorMessage: 'Download failed',
        );
        _downloadLogs.insert(0, log);
        await _storageService.saveDownloadLogs(_downloadLogs);

        activeDownload.errorMessage = 'Download failed';
        activeDownload.status = 'Error';
        notifyListeners();

        // Keep error visible for 8 seconds, then remove
        Future.delayed(const Duration(seconds: 8), () {
          _activeDownloads.remove(downloadId);
          notifyListeners();
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

  /// Cancel an ongoing active download
  void cancelDownload(String downloadId) {
    final activeDownload = _activeDownloads[downloadId];
    if (activeDownload == null) return;
    
    _cancelDownloadServiceCall(downloadId, activeDownload.needsMerge);
    _cancelConnectivitySubscription(downloadId);
    _activeDownloads.remove(downloadId);
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
    notifyListeners();
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
      stream: null,
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
      return 'YouTube is temporarily rate-limiting requests. Please wait a few minutes and try again.';
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
        // Try English first, then first available
        ClosedCaptionTrackInfo? trackInfo;
        try {
          final englishTracks = manifest.getByLanguage('en');
          if (englishTracks.isNotEmpty) {
            trackInfo = englishTracks.first;
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

  @override
  void dispose() {
    for (final sub in _connectivitySubscriptions.values) {
      sub.cancel();
    }
    _connectivitySubscriptions.clear();
    _youtubeService.dispose();
    _downloadService.dispose();
    super.dispose();
  }
}
