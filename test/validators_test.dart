import 'package:flutter_test/flutter_test.dart';
import 'package:video_downloader/models/video_info.dart';
import 'package:video_downloader/utils/validators.dart';

void main() {
  group('Validators - YouTube URLs', () {
    test('identifies standard and shorts YouTube URLs', () {
      expect(
        Validators.isValidYouTubeUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        isTrue,
      );
      expect(
        Validators.isValidYouTubeUrl('https://youtu.be/dQw4w9WgXcQ'),
        isTrue,
      );
      expect(
        Validators.isValidYouTubeUrl('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
        isTrue,
      );
      expect(
        Validators.getPlatformType('https://youtu.be/dQw4w9WgXcQ'),
        equals(PlatformType.youtube),
      );
      expect(
        Validators.extractVideoId('https://youtu.be/dQw4w9WgXcQ'),
        equals('dQw4w9WgXcQ'),
      );
    });
  });

  group('Validators - Instagram URLs', () {
    test('identifies Instagram reels, posts, and share links', () {
      const reelUrl = 'https://www.instagram.com/reel/C3_abc123XYZ/';
      const postUrl = 'https://instagram.com/p/C3_abc123XYZ/?utm_source=ig_web_copy_link';
      const tvUrl = 'https://www.instagram.com/tv/C3_abc123XYZ';

      expect(Validators.isValidInstagramUrl(reelUrl), isTrue);
      expect(Validators.isValidInstagramUrl(postUrl), isTrue);
      expect(Validators.isValidInstagramUrl(tvUrl), isTrue);

      expect(Validators.getPlatformType(reelUrl), equals(PlatformType.instagram));
      expect(Validators.getPlatformType(postUrl), equals(PlatformType.instagram));

      expect(Validators.extractInstagramId(reelUrl), equals('C3_abc123XYZ'));
      expect(Validators.extractInstagramId(postUrl), equals('C3_abc123XYZ'));
    });
  });

  group('Validators - Facebook URLs', () {
    test('identifies Facebook watch, reel, share, and video URLs', () {
      const fbWatchUrl = 'https://www.facebook.com/watch/?v=123456789012345';
      const fbReelUrl = 'https://www.facebook.com/reel/987654321098765';
      const fbShortUrl = 'https://fb.watch/abcd1234ef/';
      const fbShareUrl = 'https://www.facebook.com/share/r/abcdefghij123/';

      expect(Validators.isValidFacebookUrl(fbWatchUrl), isTrue);
      expect(Validators.isValidFacebookUrl(fbReelUrl), isTrue);
      expect(Validators.isValidFacebookUrl(fbShortUrl), isTrue);
      expect(Validators.isValidFacebookUrl(fbShareUrl), isTrue);

      expect(Validators.getPlatformType(fbWatchUrl), equals(PlatformType.facebook));
      expect(Validators.getPlatformType(fbReelUrl), equals(PlatformType.facebook));
      expect(Validators.getPlatformType(fbShortUrl), equals(PlatformType.facebook));

      expect(Validators.extractFacebookId(fbWatchUrl), equals('123456789012345'));
      expect(Validators.extractFacebookId(fbReelUrl), equals('987654321098765'));
    });
  });

  group('Validators - Twitter / X URLs', () {
    test('identifies Twitter and X status, mobile, and share URLs', () {
      const twitterUrl = 'https://twitter.com/jack/status/20';
      const xUrl = 'https://x.com/elonmusk/status/1672365478912345678?s=20';
      const mobileTwitterUrl = 'https://mobile.twitter.com/news/status/987654321098765';
      const xIUrl = 'https://x.com/i/status/112233445566778899';

      expect(Validators.isValidTwitterUrl(twitterUrl), isTrue);
      expect(Validators.isValidTwitterUrl(xUrl), isTrue);
      expect(Validators.isValidTwitterUrl(mobileTwitterUrl), isTrue);
      expect(Validators.isValidTwitterUrl(xIUrl), isTrue);

      expect(Validators.getPlatformType(twitterUrl), equals(PlatformType.twitter));
      expect(Validators.getPlatformType(xUrl), equals(PlatformType.twitter));
      expect(Validators.getPlatformType(xIUrl), equals(PlatformType.twitter));

      expect(Validators.extractTwitterId(twitterUrl), equals('20'));
      expect(Validators.extractTwitterId(xUrl), equals('1672365478912345678'));
      expect(Validators.extractTwitterId(xIUrl), equals('112233445566778899'));

      expect(Validators.extractTwitterUsername(twitterUrl), equals('jack'));
      expect(Validators.extractTwitterUsername(xUrl), equals('elonmusk'));
      expect(Validators.extractTwitterUsername(xIUrl), isNull);
    });
  });

  group('Validators - Unified isValidUrl', () {
    test('validates across all supported platforms and rejects invalid URLs', () {
      expect(Validators.isValidUrl('https://youtu.be/dQw4w9WgXcQ'), isTrue);
      expect(Validators.isValidUrl('https://www.instagram.com/reel/C3_abc123XYZ/'), isTrue);
      expect(Validators.isValidUrl('https://www.facebook.com/reel/987654321098765'), isTrue);
      expect(Validators.isValidUrl('https://x.com/jack/status/20'), isTrue);
      expect(Validators.isValidUrl('https://twitter.com/jack/status/20'), isTrue);

      expect(Validators.isValidUrl('https://google.com'), isFalse);
      expect(Validators.isValidUrl('not a url'), isFalse);
      expect(Validators.isValidUrl(''), isFalse);
    });
  });

  group('VideoInfo - Multi-platform Model', () {
    test('serializes and deserializes platform and directMediaUrls accurately', () {
      final info = VideoInfo(
        id: 'C3_abc123XYZ',
        title: 'Cool Instagram Reel',
        author: 'instacreator',
        channelId: 'instacreator',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        duration: const Duration(seconds: 45),
        viewCount: 1500,
        description: 'Test reel',
        uploadDate: DateTime.parse('2026-03-01T12:00:00Z'),
        platform: 'instagram',
        directMediaUrls: {
          'HD': 'https://cdn.instagram.com/reel_hd.mp4',
          'SD': 'https://cdn.instagram.com/reel_sd.mp4',
        },
      );

      expect(info.isSocialMedia, isTrue);

      final json = info.toJson();
      expect(json['platform'], equals('instagram'));
      expect(json['directMediaUrls']['HD'], equals('https://cdn.instagram.com/reel_hd.mp4'));

      final fromJson = VideoInfo.fromJson(json);
      expect(fromJson.platform, equals('instagram'));
      expect(fromJson.isSocialMedia, isTrue);
      expect(fromJson.directMediaUrls['HD'], equals('https://cdn.instagram.com/reel_hd.mp4'));
      expect(fromJson.directMediaUrls['SD'], equals('https://cdn.instagram.com/reel_sd.mp4'));
    });
  });
}
