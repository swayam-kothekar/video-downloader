import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/video_info.dart';
import '../models/download_log.dart';
import '../services/youtube_service.dart';
import '../services/background_download_service.dart';
import '../services/storage_service.dart';

enum VideoState { idle, loading, loaded, error, downloading, downloaded }

class VideoProvider extends ChangeNotifier {
  final YouTubeService _youtubeService;
  final BackgroundDownloadService _backgroundDownloadService;
  final StorageService _storageService;

  VideoProvider(
    this._youtubeService,
    this._backgroundDownloadService,
    this._storageService,
  ) {
    _loadDownloadLogs();
    _setupDownloadCallbacks();
  }

  // State
  VideoState _state = VideoState.idle;
  VideoInfo? _currentVideo;
  Map<String, StreamInfo> _availableStreams = {};
  String _selectedQuality = '360p';
  double _downloadProgress = 0.0;
  double _downloadSpeed = 0.0;
  String? _errorMessage;
  String? _currentDownloadId;
  String _downloadStatus = '';
  List<DownloadLog> _downloadLogs = [];
  int _retryCount = 0;
  static const int _maxRetries = 3;
  int _fileSize = 0;
  DateTime? _lastProgressUpdate;
  double _lastProgress = 0.0;

  // Getters
  VideoState get state => _state;
  VideoInfo? get currentVideo => _currentVideo;
  Map<String, StreamInfo> get availableStreams => _availableStreams;
  List<String> get availableQualities => _availableStreams.keys.toList();
  String get selectedQuality => _selectedQuality;
  double get downloadProgress => _downloadProgress;
  double get downloadSpeed => _downloadSpeed;
  String? get errorMessage => _errorMessage;
  bool get isDownloading => _state == VideoState.downloading;
  StorageService get storageService => _storageService;
  String get downloadStatus => _downloadStatus;
  List<DownloadLog> get downloadLogs => _downloadLogs;
  int get fileSize => _fileSize;

  /// Fetch video information from URL
  Future<void> fetchVideoInfo(String url) async {
    try {
      _state = VideoState.loading;
      _errorMessage = null;
      notifyListeners();

      _currentVideo = await _youtubeService.getVideoInfo(url);
      _availableStreams = await _youtubeService.getAvailableStreams(
        _currentVideo!.id,
      );

      // Set quality to highest available video quality
      if (_availableStreams.isNotEmpty) {
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
          _selectedQuality = videoQualities.first;
        } else {
          // If only audio is available, select it
          _selectedQuality = _availableStreams.keys.first;
        }
      }

      _state = VideoState.loaded;
      notifyListeners();
    } catch (e) {
      _state = VideoState.error;
      _errorMessage = e.toString();
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

  /// Download the current video
  Future<void> downloadVideo() async {
    print('VideoProvider: downloadVideo() called');

    if (_currentVideo == null ||
        !_availableStreams.containsKey(_selectedQuality)) {
      print('VideoProvider: No video or quality not available');
      _errorMessage = 'No video selected or quality not available';
      _state = VideoState.error;
      notifyListeners();
      return;
    }

    try {
      print('VideoProvider: Requesting storage permission...');
      // Request storage permission
      final hasPermission = await _storageService.requestStoragePermission();
      if (!hasPermission) {
        print('VideoProvider: Storage permission denied');
        _errorMessage = 'Storage permission denied';
        _state = VideoState.error;
        notifyListeners();
        return;
      }

      // Request notification permission (required for Android 13+)
      print('VideoProvider: Requesting notification permission...');
      final hasNotificationPermission = await _storageService
          .requestNotificationPermission();
      if (!hasNotificationPermission) {
        print('VideoProvider: Notification permission denied');
        // Continue anyway - downloads will work but without notifications
      }

      print('VideoProvider: Permission granted, preparing download...');

      _retryCount = 0; // Reset retry count for new download
      _state = VideoState.downloading;
      _downloadProgress = 0.0;
      _downloadSpeed = 0.0;
      _downloadStatus = 'Preparing download...';
      notifyListeners();

      final stream = _availableStreams[_selectedQuality]!;
      final downloadDir = await _storageService.getDownloadDirectory();

      print('VideoProvider: Download directory: $downloadDir');

      // Get file size from stream
      _fileSize = stream.size.totalBytes;
      print('VideoProvider: File size: $_fileSize bytes');

      // Determine file extension based on quality
      String extension = 'mp4';
      if (_selectedQuality == 'Audio Only') {
        extension = 'm4a';
      }

      final fileName = _storageService.generateFileName(
        _currentVideo!.title,
        _selectedQuality,
        extension,
      );

      print('VideoProvider: Generated filename: $fileName');

      // Start background download
      _downloadStatus = 'Starting download...';
      notifyListeners();

      print('VideoProvider: Calling background download service...');

      final taskId = await _backgroundDownloadService.startDownload(
        url: stream.url.toString(),
        savePath: downloadDir,
        fileName: fileName,
      );

      if (taskId == null) {
        print('VideoProvider: Background download returned null task ID');
        throw Exception('Failed to start download');
      }

      print('VideoProvider: Download started with task ID: $taskId');
      _currentDownloadId = taskId;
      _downloadStatus = 'Downloading...';
      notifyListeners();
    } catch (e, stackTrace) {
      print('VideoProvider: Error in downloadVideo: $e');
      print('Stack trace: $stackTrace');

      // Create error log
      if (_currentVideo != null) {
        final log = DownloadLog(
          videoTitle: _currentVideo!.title,
          quality: _selectedQuality,
          downloadDate: DateTime.now(),
          isSuccess: false,
          errorMessage: e.toString(),
        );
        _downloadLogs.insert(0, log);
        await _storageService.saveDownloadLogs(_downloadLogs);
      }

      _state = VideoState.error;
      _errorMessage = 'Download failed: ${e.toString()}';
      _downloadStatus = '';
      _currentDownloadId = null;
      notifyListeners();
    }
  }

  /// Cancel the current download
  void cancelDownload() {
    if (_currentDownloadId != null) {
      _backgroundDownloadService.cancelDownload(_currentDownloadId!);
      _state = VideoState.loaded;
      _downloadProgress = 0.0;
      _downloadSpeed = 0.0;
      _currentDownloadId = null;
      notifyListeners();
    }
  }

  /// Reset state
  void reset() {
    _state = VideoState.idle;
    _currentVideo = null;
    _availableStreams = {};
    _selectedQuality = '360p';
    _downloadProgress = 0.0;
    _downloadSpeed = 0.0;
    _errorMessage = null;
    _currentDownloadId = null;
    notifyListeners();
  }

  /// Setup download progress callbacks
  void _setupDownloadCallbacks() {
    _backgroundDownloadService.onProgressCallback = (taskId, progress) {
      if (taskId == _currentDownloadId) {
        final now = DateTime.now();
        final progressFraction = progress / 100.0;

        // Calculate speed if we have previous data
        if (_lastProgressUpdate != null && _fileSize > 0) {
          final timeDiff =
              now.difference(_lastProgressUpdate!).inMilliseconds /
              1000.0; // seconds
          if (timeDiff > 0) {
            final progressDiff = progressFraction - _lastProgress;
            final bytesDiff = (progressDiff * _fileSize).abs();
            _downloadSpeed = bytesDiff / timeDiff; // bytes per second
          }
        }

        _lastProgressUpdate = now;
        _lastProgress = progressFraction;
        _downloadProgress = progressFraction;
        notifyListeners();
      }
    };

    _backgroundDownloadService.onCompleteCallback = (taskId) async {
      if (taskId == _currentDownloadId && _currentVideo != null) {
        // Create download log
        final log = DownloadLog(
          videoTitle: _currentVideo!.title,
          quality: _selectedQuality,
          downloadDate: DateTime.now(),
          isSuccess: true,
        );
        _downloadLogs.insert(0, log);
        await _storageService.saveDownloadLogs(_downloadLogs);

        _state = VideoState.downloaded;
        _downloadProgress = 1.0;
        _downloadStatus = 'Complete';
        _currentDownloadId = null;
        _retryCount = 0; // Reset retry count
        notifyListeners();
      }
    };

    _backgroundDownloadService.onErrorCallback = (taskId, error) async {
      if (taskId == _currentDownloadId && _currentVideo != null) {
        // Check if we should retry
        if (_retryCount < _maxRetries) {
          _retryCount++;
          print(
            'VideoProvider: Download failed, retrying... (Attempt $_retryCount/$_maxRetries)',
          );

          _downloadStatus = 'Retrying... (Attempt $_retryCount/$_maxRetries)';
          notifyListeners();

          // Wait a bit before retrying
          await Future.delayed(const Duration(seconds: 2));

          // Retry the download
          final stream = _availableStreams[_selectedQuality]!;
          final downloadDir = await _storageService.getDownloadDirectory();

          String extension = 'mp4';
          if (_selectedQuality == 'Audio Only') {
            extension = 'm4a';
          }

          final fileName = _storageService.generateFileName(
            _currentVideo!.title,
            _selectedQuality,
            extension,
          );

          final newTaskId = await _backgroundDownloadService.startDownload(
            url: stream.url.toString(),
            savePath: downloadDir,
            fileName: fileName,
          );

          if (newTaskId != null) {
            _currentDownloadId = newTaskId;
            _downloadStatus = 'Downloading...';
            notifyListeners();
            return; // Exit early, don't create error log yet
          }
        }

        // Max retries exceeded or retry failed, create error log
        print('VideoProvider: Download failed after $_retryCount attempts');
        final log = DownloadLog(
          videoTitle: _currentVideo!.title,
          quality: _selectedQuality,
          downloadDate: DateTime.now(),
          isSuccess: false,
          errorMessage: 'Failed after $_retryCount attempts: $error',
        );
        _downloadLogs.insert(0, log);
        await _storageService.saveDownloadLogs(_downloadLogs);

        _state = VideoState.error;
        _errorMessage = 'Download failed after $_retryCount attempts: $error';
        _downloadStatus = '';
        _currentDownloadId = null;
        _retryCount = 0; // Reset retry count
        notifyListeners();
      }
    };
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

  @override
  void dispose() {
    _youtubeService.dispose();
    _backgroundDownloadService.dispose();
    super.dispose();
  }
}
