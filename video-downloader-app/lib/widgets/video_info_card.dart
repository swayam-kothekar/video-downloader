import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/video_info.dart';
import '../utils/validators.dart';
import '../utils/constants.dart';
import '../providers/video_provider.dart';

class VideoInfoCard extends StatelessWidget {
  final VideoInfo video;

  const VideoInfoCard({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: AppConstants.animationNormal),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(scale: 0.9 + (value * 0.1), child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          gradient: LinearGradient(
            colors: [
              AppConstants.darkCard,
              AppConstants.darkCard.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppConstants.primaryPurple.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppConstants.radiusLarge),
                topRight: Radius.circular(AppConstants.radiusLarge),
              ),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: AppConstants.darkSurface,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: AppConstants.darkSurface,
                      child: const Icon(Icons.error, size: 48),
                    ),
                  ),
                  // Duration badge
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        Validators.formatDuration(video.duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Video Details
            Padding(
              padding: const EdgeInsets.all(AppConstants.spaceMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    video.title,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppConstants.spaceSmall),

                  // Channel Name
                  Row(
                    children: [
                      const Icon(
                        Icons.account_circle,
                        size: 20,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: AppConstants.spaceSmall),
                      Expanded(
                        child: Text(
                          video.author,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spaceSmall),

                  // File size only
                  Consumer<VideoProvider>(
                    builder: (context, provider, child) {
                      final selectedStream =
                          provider.availableStreams[provider.selectedQuality];
                      final fileSize = selectedStream?.size.totalBytes ?? 0;
                      final fileSizeMB = (fileSize / (1024 * 1024))
                          .toStringAsFixed(1);

                      return Row(
                        children: [
                          const Icon(
                            Icons.file_download,
                            size: 16,
                            color: Colors.white60,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$fileSizeMB MB',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white60),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
