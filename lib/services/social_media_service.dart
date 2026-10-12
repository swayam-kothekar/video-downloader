import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:direct_link/direct_link.dart';
import '../models/video_info.dart';
import '../utils/validators.dart';

class SocialMediaResult {
  final VideoInfo videoInfo;
  final Map<String, String> qualities; // Quality label (e.g. 'HD', 'SD', '720p') -> Direct URL

  SocialMediaResult({
    required this.videoInfo,
    required this.qualities,
  });
}

class SocialMediaService {
  final DirectLink _directLink = DirectLink();
  final http.Client _client = http.Client();

  /// Fetches video details and direct download streams for Instagram or Facebook
  Future<SocialMediaResult> getVideoData(String url, PlatformType platform) async {
    final normalizedUrl = url.trim();

    // Strategy 1: Attempt extraction using the official Flutter package 'direct_link'
    try {
      debugPrint('SocialMediaService: Trying direct_link package for $normalizedUrl');
      final SiteModel? model = await _directLink
          .check(normalizedUrl, timeoutInterval: 10.0)
          .timeout(const Duration(seconds: 10));

      if (model != null && model.links != null && model.links!.isNotEmpty) {
        final Map<String, String> qualities = {};
        for (final link in model.links!) {
          if (link.link.isNotEmpty && link.link.startsWith('http')) {
            final label = link.quality.isNotEmpty ? link.quality : 'HD';
            qualities[label] = link.link;
          }
        }

        if (qualities.isNotEmpty) {
          final id = platform == PlatformType.instagram
              ? (Validators.extractInstagramId(normalizedUrl) ?? 'ig_${DateTime.now().millisecondsSinceEpoch}')
              : (platform == PlatformType.facebook
                  ? (Validators.extractFacebookId(normalizedUrl) ?? 'fb_${DateTime.now().millisecondsSinceEpoch}')
                  : (Validators.extractTwitterId(normalizedUrl) ?? 'tw_${DateTime.now().millisecondsSinceEpoch}'));

          final title = (model.title != null && model.title!.trim().isNotEmpty)
              ? model.title!.trim()
              : (platform == PlatformType.instagram
                  ? 'Instagram Reel'
                  : (platform == PlatformType.facebook ? 'Facebook Video' : 'X Video'));

          final author = platform == PlatformType.instagram
              ? 'Instagram'
              : (platform == PlatformType.facebook
                  ? 'Facebook'
                  : (Validators.extractTwitterUsername(normalizedUrl) ?? 'X'));

          final videoInfo = VideoInfo(
            id: id,
            title: title,
            author: author,
            channelId: platform.name,
            thumbnailUrl: model.thumbnail ?? '',
            duration: _parseDuration(model.duration),
            viewCount: 0,
            description: title,
            uploadDate: DateTime.now(),
            platform: platform.name,
            directMediaUrls: qualities,
          );

          debugPrint('SocialMediaService: Successfully resolved via direct_link package');
          return SocialMediaResult(videoInfo: videoInfo, qualities: qualities);
        }
      }
    } catch (e) {
      debugPrint('SocialMediaService: direct_link package failed or timed out: $e');
    }

    // Strategy 2: Attempt yt-dlp native extractor if available on system
    try {
      final ytdlResult = await _fetchViaYtDlp(normalizedUrl, platform);
      if (ytdlResult != null) {
        debugPrint('SocialMediaService: Successfully resolved via native yt-dlp');
        return ytdlResult;
      }
    } catch (e) {
      debugPrint('SocialMediaService: yt-dlp attempt failed: $e');
    }

    // Strategy 3: Dedicated platform scrapers
    if (platform == PlatformType.instagram) {
      final igResult = await _fetchInstagramDirect(normalizedUrl);
      if (igResult != null) {
        debugPrint('SocialMediaService: Successfully resolved via direct Instagram scraper');
        return igResult;
      }
    } else if (platform == PlatformType.facebook) {
      final fbResult = await _fetchFacebookDirect(normalizedUrl);
      if (fbResult != null) {
        debugPrint('SocialMediaService: Successfully resolved via direct Facebook scraper');
        return fbResult;
      }
    } else if (platform == PlatformType.twitter) {
      final twResult = await _fetchTwitterDirect(normalizedUrl);
      if (twResult != null) {
        debugPrint('SocialMediaService: Successfully resolved via direct Twitter/X scraper');
        return twResult;
      }
    }

    // Strategy 4: Fallback to public resolvers
    final fallbackResult = await _fetchViaPublicResolver(normalizedUrl, platform);
    if (fallbackResult != null) {
      debugPrint('SocialMediaService: Successfully resolved via public fallback resolver');
      return fallbackResult;
    }

    throw Exception(
      'Unable to extract video for this ${Validators.getPlatformName(normalizedUrl)} URL. '
      'Please ensure the reel/video is public and accessible.',
    );
  }

  /// System yt-dlp extractor (when available in environment)
  Future<SocialMediaResult?> _fetchViaYtDlp(String url, PlatformType platform) async {
    try {
      final result = await Process.run('yt-dlp', [
        '--dump-json',
        '--no-playlist',
        '--no-warnings',
        url,
      ]).timeout(const Duration(seconds: 15));

      if (result.exitCode == 0 && result.stdout.toString().isNotEmpty) {
        final data = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
        final Map<String, String> qualities = {};

        // Extract direct format streams
        if (data.containsKey('formats') && data['formats'] is List) {
          final formats = data['formats'] as List;
          for (final f in formats.reversed) {
            if (f is Map<String, dynamic>) {
              final vcodec = f['vcodec']?.toString();
              final directUrl = f['url']?.toString();
              if (directUrl != null && directUrl.startsWith('http') && vcodec != 'none') {
                final formatNote = f['format_note']?.toString();
                final height = f['height']?.toString();
                final label = formatNote ?? (height != null ? '${height}p' : 'MP4');
                if (!qualities.containsKey(label)) {
                  qualities[label] = directUrl;
                }
              }
            }
          }
        }

        // Fallback to primary direct url
        if (qualities.isEmpty && data['url'] != null) {
          qualities['HD'] = data['url'].toString();
        }

        if (qualities.isNotEmpty) {
          final id = data['id']?.toString() ??
              (platform == PlatformType.instagram
                  ? (Validators.extractInstagramId(url) ?? 'ig_video')
                  : (platform == PlatformType.facebook
                      ? (Validators.extractFacebookId(url) ?? 'fb_video')
                      : (Validators.extractTwitterId(url) ?? 'tw_video')));

          final title = data['title']?.toString() ??
              (platform == PlatformType.instagram
                  ? 'Instagram Reel'
                  : (platform == PlatformType.facebook ? 'Facebook Video' : 'X Video'));
          final author = data['uploader']?.toString() ??
              data['uploader_id']?.toString() ??
              (platform == PlatformType.instagram
                  ? 'Instagram'
                  : (platform == PlatformType.facebook
                      ? 'Facebook'
                      : (Validators.extractTwitterUsername(url) ?? 'X')));
          final thumbnail = data['thumbnail']?.toString() ?? '';
          final durationSec = (data['duration'] is num) ? (data['duration'] as num).toInt() : 0;

          return SocialMediaResult(
            videoInfo: VideoInfo(
              id: id,
              title: title,
              author: author,
              channelId: platform.name,
              thumbnailUrl: thumbnail,
              duration: Duration(seconds: durationSec),
              viewCount: (data['view_count'] is num) ? (data['view_count'] as num).toInt() : 0,
              description: data['description']?.toString() ?? title,
              uploadDate: DateTime.now(),
              platform: platform.name,
              directMediaUrls: qualities,
            ),
            qualities: qualities,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Direct Instagram Reel/Post Scraper
  Future<SocialMediaResult?> _fetchInstagramDirect(String url) async {
    final shortcode = Validators.extractInstagramId(url);
    if (shortcode == null) return null;

    final candidateUrls = [
      'https://www.instagram.com/reel/$shortcode/embed/captioned/',
      'https://www.instagram.com/p/$shortcode/embed/captioned/',
      'https://www.instagram.com/reel/$shortcode/',
      'https://www.instagram.com/p/$shortcode/',
    ];

    for (final candidateUrl in candidateUrls) {
      try {
        final res = await _client.get(
          Uri.parse(candidateUrl),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Sec-Fetch-Mode': 'navigate',
          },
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final body = res.body;

          // 1. Look for video_url in embedded script JSON
          final videoUrlMatch = RegExp(r'"video_url"\s*:\s*"([^"]+)"').firstMatch(body) ??
              RegExp(r'video_url\\?":\s*"([^"]+)"').firstMatch(body);

          String? videoUrl;
          if (videoUrlMatch != null) {
            videoUrl = _decodeEscapedUrl(videoUrlMatch.group(1)!);
          }

          // 2. Look for og:video in meta tags
          if (videoUrl == null || !videoUrl.startsWith('http')) {
            final ogMatch = RegExp(
                  r"""<meta[^>]+property=['"]og:video(?::secure_url)?['"][^>]+content=['"]([^'"]+)['"]""",
                  caseSensitive: false,
                ).firstMatch(body) ??
                RegExp(
                  r"""<meta[^>]+content=['"]([^'"]+)['"][^>]+property=['"]og:video(?::secure_url)?['"]""",
                  caseSensitive: false,
                ).firstMatch(body);
            if (ogMatch != null) {
              videoUrl = _decodeEscapedUrl(ogMatch.group(1)!);
            }
          }

          if (videoUrl != null && videoUrl.startsWith('http')) {
            // Extract thumbnail
            String thumbnailUrl = '';
            final thumbMatch = RegExp(
                  r"""<meta[^>]+property=['"]og:image['"][^>]+content=['"]([^'"]+)['"]""",
                  caseSensitive: false,
                ).firstMatch(body) ??
                RegExp(r'class="EmbeddedMediaImage"[^>]*src="([^"]+)"').firstMatch(body);
            if (thumbMatch != null) {
              thumbnailUrl = _decodeEscapedUrl(thumbMatch.group(1)!);
            }

            // Extract title
            String title = 'Instagram Reel ($shortcode)';
            final titleMatch = RegExp(
              r"""<meta[^>]+property=['"]og:title['"][^>]+content=['"]([^'"]+)['"]""",
              caseSensitive: false,
            ).firstMatch(body);
            if (titleMatch != null) {
              title = _cleanHtmlTitle(titleMatch.group(1)!);
            }

            final qualities = {'HD': videoUrl};
            return SocialMediaResult(
              videoInfo: VideoInfo(
                id: shortcode,
                title: title,
                author: 'Instagram',
                channelId: 'instagram',
                thumbnailUrl: thumbnailUrl,
                duration: Duration.zero,
                viewCount: 0,
                description: title,
                uploadDate: DateTime.now(),
                platform: 'instagram',
                directMediaUrls: qualities,
              ),
              qualities: qualities,
            );
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Direct Facebook Video / Reel Scraper
  Future<SocialMediaResult?> _fetchFacebookDirect(String url) async {
    final videoId = Validators.extractFacebookId(url) ?? 'fb_${DateTime.now().millisecondsSinceEpoch}';

    final targetUrls = [
      url.replaceAll('www.', 'm.').replaceAll('web.', 'm.').replaceAll('facebook.com', 'm.facebook.com'),
      url.replaceAll('www.', 'mbasic.').replaceAll('web.', 'mbasic.').replaceAll('facebook.com', 'mbasic.facebook.com'),
      url,
    ];

    for (final targetUrl in targetUrls) {
      try {
        final res = await _client.get(
          Uri.parse(targetUrl),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
          },
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final body = res.body;
          final Map<String, String> qualities = {};

          // HD Regex checks
          final hdRegexes = [
            RegExp(r"""browser_native_hd_url['"]?\s*:\s*['"]([^'"]+)['"]"""),
            RegExp(r"""playable_url_quality_hd['"]?\s*:\s*['"]([^'"]+)['"]"""),
            RegExp(r"""hd_src['"]?\s*:\s*['"]([^'"]+)['"]"""),
            RegExp(r"""hd_src_no_ratelimit['"]?\s*:\s*['"]([^'"]+)['"]"""),
          ];

          for (final r in hdRegexes) {
            final match = r.firstMatch(body);
            if (match != null) {
              final direct = _decodeEscapedUrl(match.group(1)!);
              if (direct.startsWith('http')) {
                qualities['HD'] = direct;
                break;
              }
            }
          }

          // SD Regex checks
          final sdRegexes = [
            RegExp(r"""browser_native_sd_url['"]?\s*:\s*['"]([^'"]+)['"]"""),
            RegExp(r"""playable_url['"]?\s*:\s*['"]([^'"]+)['"]"""),
            RegExp(r"""sd_src['"]?\s*:\s*['"]([^'"]+)['"]"""),
            RegExp(r"""sd_src_no_ratelimit['"]?\s*:\s*['"]([^'"]+)['"]"""),
          ];

          for (final r in sdRegexes) {
            final match = r.firstMatch(body);
            if (match != null) {
              final direct = _decodeEscapedUrl(match.group(1)!);
              if (direct.startsWith('http')) {
                qualities['SD'] = direct;
                break;
              }
            }
          }

          // Fallback to og:video
          if (qualities.isEmpty) {
            final ogMatch = RegExp(
              r"""<meta[^>]+property=['"]og:video(?::secure_url)?['"][^>]+content=['"]([^'"]+)['"]""",
              caseSensitive: false,
            ).firstMatch(body);
            if (ogMatch != null) {
              final direct = _decodeEscapedUrl(ogMatch.group(1)!);
              if (direct.startsWith('http')) {
                qualities['Video'] = direct;
              }
            }
          }

          if (qualities.isNotEmpty) {
            // Extract title
            String title = 'Facebook Video';
            final titleMatch = RegExp(
                  r"""<meta[^>]+property=['"]og:title['"][^>]+content=['"]([^'"]+)['"]""",
                  caseSensitive: false,
                ).firstMatch(body) ??
                RegExp(r'<title>([^<]+)</title>', caseSensitive: false).firstMatch(body);
            if (titleMatch != null) {
              title = _cleanHtmlTitle(titleMatch.group(1)!);
            }

            // Extract thumbnail
            String thumb = '';
            final thumbMatch = RegExp(
              r"""<meta[^>]+property=['"]og:image['"][^>]+content=['"]([^'"]+)['"]""",
              caseSensitive: false,
            ).firstMatch(body);
            if (thumbMatch != null) {
              thumb = _decodeEscapedUrl(thumbMatch.group(1)!);
            }

            return SocialMediaResult(
              videoInfo: VideoInfo(
                id: videoId,
                title: title,
                author: 'Facebook',
                channelId: 'facebook',
                thumbnailUrl: thumb,
                duration: Duration.zero,
                viewCount: 0,
                description: title,
                uploadDate: DateTime.now(),
                platform: 'facebook',
                directMediaUrls: qualities,
              ),
              qualities: qualities,
            );
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Direct Twitter / X Video Scraper via public syndication & FixTweet APIs
  Future<SocialMediaResult?> _fetchTwitterDirect(String url) async {
    final statusId = Validators.extractTwitterId(url);
    if (statusId == null) return null;

    final username = Validators.extractTwitterUsername(url);
    final candidateEndpoints = [
      if (username != null) 'https://api.fxtwitter.com/$username/status/$statusId',
      'https://api.fxtwitter.com/i/status/$statusId',
      'https://api.vxtwitter.com/Twitter/status/$statusId',
    ];

    for (final endpoint in candidateEndpoints) {
      try {
        final res = await _client.get(
          Uri.parse(endpoint),
          headers: {
            'Accept': 'application/json',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          },
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);

          // 1. FixTweet (fxtwitter) response schema
          if (data is Map<String, dynamic> &&
              data['code'] == 200 &&
              data['tweet'] is Map<String, dynamic>) {
            final tweet = data['tweet'] as Map<String, dynamic>;
            final media = tweet['media'];
            final Map<String, String> qualities = {};
            String thumb = '';
            int durationSec = 0;

            if (media is Map<String, dynamic> && media['videos'] is List) {
              final videos = media['videos'] as List;
              if (videos.isNotEmpty) {
                final primaryVideo = videos[0];
                if (primaryVideo is Map<String, dynamic>) {
                  thumb = primaryVideo['thumbnail_url']?.toString() ?? '';
                  if (primaryVideo['duration'] is num) {
                    durationSec = (primaryVideo['duration'] as num).toInt();
                  }

                  // Parse variants if available
                  if (primaryVideo['variants'] is List) {
                    final variants = (primaryVideo['variants'] as List)
                        .whereType<Map<String, dynamic>>()
                        .where((v) {
                      final u = v['url']?.toString() ?? '';
                      return u.startsWith('http') &&
                          (u.contains('.mp4') ||
                              (v['content_type']?.toString().contains('mp4') ?? false));
                    }).toList();

                    // Sort descending by bitrate
                    variants.sort((a, b) {
                      final bBit = (b['bitrate'] is num) ? (b['bitrate'] as num).toInt() : 0;
                      final aBit = (a['bitrate'] is num) ? (a['bitrate'] as num).toInt() : 0;
                      return bBit.compareTo(aBit);
                    });

                    for (int i = 0; i < variants.length; i++) {
                      final vUrl = variants[i]['url'].toString();
                      String label;
                      if (i == 0) {
                        label = 'HD';
                      } else if (i == 1) {
                        label = 'Medium';
                      } else {
                        label = 'SD';
                      }
                      if (!qualities.containsKey(label)) {
                        qualities[label] = vUrl;
                      }
                    }
                  }

                  // Fallback to primary direct url
                  if (qualities.isEmpty && primaryVideo['url'] != null) {
                    qualities['HD'] = primaryVideo['url'].toString();
                  }
                }
              }
            }

            if (qualities.isNotEmpty) {
              final text = tweet['text']?.toString().trim();
              final title = (text != null && text.isNotEmpty) ? text : 'X Video ($statusId)';
              final authorName = tweet['author'] is Map<String, dynamic>
                  ? (tweet['author']['name']?.toString() ?? '@${tweet['author']['screen_name']}')
                  : (username != null ? '@$username' : 'X');

              if (thumb.isEmpty && tweet['author'] is Map<String, dynamic>) {
                thumb = tweet['author']['avatar_url']?.toString() ?? '';
              }

              return SocialMediaResult(
                videoInfo: VideoInfo(
                  id: statusId,
                  title: title,
                  author: authorName,
                  channelId: 'twitter',
                  thumbnailUrl: thumb,
                  duration: Duration(seconds: durationSec),
                  viewCount: (tweet['views'] is num) ? (tweet['views'] as num).toInt() : 0,
                  description: title,
                  uploadDate: DateTime.now(),
                  platform: 'twitter',
                  directMediaUrls: qualities,
                ),
                qualities: qualities,
              );
            }
          }

          // 2. vxTwitter response schema
          if (data is Map<String, dynamic> && data.containsKey('tweetURL')) {
            final videoUrl = data['video_url']?.toString();
            if (videoUrl != null && videoUrl.startsWith('http')) {
              final qualities = {'HD': videoUrl};
              final title = data['text']?.toString().trim() ?? 'X Video ($statusId)';
              final authorName = data['user_name']?.toString() ??
                  data['user_screen_name']?.toString() ??
                  (username != null ? '@$username' : 'X');

              return SocialMediaResult(
                videoInfo: VideoInfo(
                  id: statusId,
                  title: title,
                  author: authorName,
                  channelId: 'twitter',
                  thumbnailUrl: '',
                  duration: Duration.zero,
                  viewCount: 0,
                  description: title,
                  uploadDate: DateTime.now(),
                  platform: 'twitter',
                  directMediaUrls: qualities,
                ),
                qualities: qualities,
              );
            }
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// Public fallback resolver
  Future<SocialMediaResult?> _fetchViaPublicResolver(String url, PlatformType platform) async {
    try {
      final encodedUrl = Uri.encodeComponent(url);
      final res = await _client.get(
        Uri.parse('https://api.vkrdownloader.com/server?vkr=$encodedUrl'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final Map<String, String> qualities = {};

        if (data is Map<String, dynamic> && data['data'] != null) {
          final info = data['data'];
          if (info is Map<String, dynamic>) {
            final downloads = info['downloads'];
            if (downloads is List) {
              for (final d in downloads) {
                if (d is Map<String, dynamic>) {
                  final link = d['url']?.toString();
                  final format = d['format_id']?.toString() ?? d['quality']?.toString() ?? 'HD';
                  if (link != null && link.startsWith('http')) {
                    qualities[format] = link;
                  }
                }
              }
            }

            if (qualities.isEmpty && info['url'] != null) {
              qualities['HD'] = info['url'].toString();
            }

            if (qualities.isNotEmpty) {
              final title = info['title']?.toString() ??
                  (platform == PlatformType.instagram
                      ? 'Instagram Reel'
                      : (platform == PlatformType.facebook ? 'Facebook Video' : 'X Video'));
              final thumbnail = info['thumbnail']?.toString() ?? '';
              final id = platform == PlatformType.instagram
                  ? (Validators.extractInstagramId(url) ?? 'ig_video')
                  : (platform == PlatformType.facebook
                      ? (Validators.extractFacebookId(url) ?? 'fb_video')
                      : (Validators.extractTwitterId(url) ?? 'tw_video'));
              final author = platform == PlatformType.instagram
                  ? 'Instagram'
                  : (platform == PlatformType.facebook
                      ? 'Facebook'
                      : (Validators.extractTwitterUsername(url) ?? 'X'));

              return SocialMediaResult(
                videoInfo: VideoInfo(
                  id: id,
                  title: title,
                  author: author,
                  channelId: platform.name,
                  thumbnailUrl: thumbnail,
                  duration: Duration.zero,
                  viewCount: 0,
                  description: title,
                  uploadDate: DateTime.now(),
                  platform: platform.name,
                  directMediaUrls: qualities,
                ),
                qualities: qualities,
              );
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  String _decodeEscapedUrl(String str) {
    String decoded = str
        .replaceAll(r'\/', '/')
        .replaceAll(r'\u0025', '%')
        .replaceAll(r'\u0026', '&')
        .replaceAll('&amp;', '&');
    try {
      if (decoded.contains(r'\u')) {
        decoded = jsonDecode('"$decoded"');
      }
    } catch (_) {}
    return decoded;
  }

  String _cleanHtmlTitle(String raw) {
    String clean = raw
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
    if (clean.endsWith('| Facebook')) {
      clean = clean.replaceAll('| Facebook', '').trim();
    }
    if (clean.endsWith('| Instagram')) {
      clean = clean.replaceAll('| Instagram', '').trim();
    }
    if (clean.endsWith('| X')) {
      clean = clean.replaceAll('| X', '').trim();
    }
    if (clean.endsWith('/ X')) {
      clean = clean.replaceAll('/ X', '').trim();
    }
    if (clean.endsWith('/ Twitter')) {
      clean = clean.replaceAll('/ Twitter', '').trim();
    }
    return clean.isEmpty ? 'Video' : clean;
  }

  Duration _parseDuration(String? str) {
    if (str == null || str.isEmpty) return Duration.zero;
    final parts = str.split(':').map((s) => int.tryParse(s) ?? 0).toList();
    if (parts.length == 3) {
      return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    } else if (parts.length == 2) {
      return Duration(minutes: parts[0], seconds: parts[1]);
    } else if (parts.length == 1) {
      return Duration(seconds: parts[0]);
    }
    return Duration.zero;
  }

  void dispose() {
    _client.close();
  }
}
