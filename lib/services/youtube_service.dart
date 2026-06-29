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
      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [
          YoutubeApiClient.android,
          YoutubeApiClient.ios,
        ],
      );
      final Map<String, StreamInfo> streams = {};

      // Get all muxed streams (video + audio combined)
      // These typically include 144p, 240p, 360p, 480p, 720p
      final muxedStreams = manifest.muxed.sortByVideoQuality();

      // Add all available muxed streams
      for (var stream in muxedStreams) {
        final quality = stream.qualityLabel;

        // Only add if we don't already have this quality
        if (!streams.containsKey(quality)) {
          streams[quality] = stream;
        }
      }

      // Get all video-only streams (usually high resolution like 480p, 720p, 1080p, 1440p, 2160p)
      final videoOnlyStreams = manifest.videoOnly.sortByVideoQuality();

      // Add video-only streams if we don't already have them from the muxed streams
      for (var stream in videoOnlyStreams) {
        final quality = stream.qualityLabel;

        if (!streams.containsKey(quality)) {
          streams[quality] = stream;
        } else {
          final existingStream = streams[quality]!;
          // If the existing stream is NOT muxed, we prefer the MP4 container for videoOnly streams
          if (existingStream is! MuxedStreamInfo) {
            final isExistingMp4 = existingStream.container.name.toLowerCase() == 'mp4';
            final isNewMp4 = stream.container.name.toLowerCase() == 'mp4';
            
            if (!isExistingMp4 && isNewMp4) {
              streams[quality] = stream;
            }
          }
        }
      }

      // Add audio-only option with best quality (prefer MP4/M4A container)
      final audioStreams = manifest.audioOnly.toList();
      if (audioStreams.isNotEmpty) {
        audioStreams.sort((a, b) => b.bitrate.compareTo(a.bitrate)); // sort descending by bitrate
        
        final mp4AudioStreams = audioStreams
            .where((s) =>
                s.container.name.toLowerCase() == 'mp4' ||
                s.container.name.toLowerCase() == 'm4a')
            .toList();
            
        final audioStream = mp4AudioStreams.isNotEmpty ? mp4AudioStreams.first : audioStreams.first;
        streams['Audio Only'] = audioStream;
      }

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
      return await _yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [
          YoutubeApiClient.android,
          YoutubeApiClient.ios,
        ],
      );
    } catch (e) {
      throw Exception('Failed to fetch video manifest: ${e.toString()}');
    }
  }

  /// Check if a stream contains both audio and video (is muxed)
  bool isStreamMuxed(StreamInfo stream) {
    return stream is MuxedStreamInfo;
  }

  /// Get closed captions manifest for a video
  Future<ClosedCaptionManifest> getClosedCaptionManifest(String videoId) async {
    try {
      return await _yt.videos.closedCaptions.getManifest(videoId);
    } catch (e) {
      throw Exception('Failed to fetch subtitles manifest: ${e.toString()}');
    }
  }

  /// Get closed caption track from track info
  Future<ClosedCaptionTrack> getClosedCaptionTrack(ClosedCaptionTrackInfo trackInfo) async {
    try {
      return await _yt.videos.closedCaptions.get(trackInfo);
    } catch (e) {
      throw Exception('Failed to fetch subtitle track: ${e.toString()}');
    }
  }

  /// Cleanup resources
  void dispose() {
    _yt.close();
  }
}
