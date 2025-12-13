import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/video_info.dart';

class YouTubeService {
  late final YoutubeExplode _yt;

  YouTubeService() {
    _yt = YoutubeExplode();
  }

  /// Search Videormation from URL
  Future<VideoInfo> getVideoInfo(String url) async {
    try {
      final video = await _yt.videos.get(url);

      return VideoInfo(
        id: video.id.value,
        title: video.title,
        author: video.author,
        channelId: video.channelId.value,
        thumbnailUrl: video.thumbnails.highResUrl,
        duration: video.duration ?? Duration.zero,
        viewCount: video.engagement.viewCount,
        description: video.description,
        uploadDate: video.uploadDate ?? DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to fetch video info: ${e.toString()}');
    }
  }

  /// Get available stream qualities for a video
  Future<Map<String, StreamInfo>> getAvailableStreams(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final Map<String, StreamInfo> streams = {};

      // Get all muxed streams (video + audio combined)
      // These typically include 144p, 240p, 360p, 480p, 720p
      final muxedStreams = manifest.muxed.sortByVideoQuality();

      // Add all available muxed streams
      for (var stream in muxedStreams) {
        final height = stream.videoQuality.name;
        final quality = '${height}p';

        // Only add if we don't already have this quality
        if (!streams.containsKey(quality)) {
          streams[quality] = stream;
        }
      }

      // Add audio-only option with best quality
      final audioStream = manifest.audioOnly.withHighestBitrate();
      streams['Audio Only'] = audioStream;

      // If no streams found, throw an error
      if (streams.isEmpty) {
        throw Exception('No streams available for this video');
      }

      return streams;
    } catch (e) {
      throw Exception('Failed to fetch video streams: ${e.toString()}');
    }
  }

  /// Get stream manifest for a video
  Future<StreamManifest> getVideoManifest(String videoId) async {
    try {
      return await _yt.videos.streamsClient.getManifest(videoId);
    } catch (e) {
      throw Exception('Failed to fetch video manifest: ${e.toString()}');
    }
  }

  /// Check if a stream contains both audio and video (is muxed)
  bool isStreamMuxed(StreamInfo stream) {
    return stream is MuxedStreamInfo;
  }

  /// Cleanup resources
  void dispose() {
    _yt.close();
  }
}
