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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppConstants.border : const Color(0xFFE4E4E7);
    
    return AnimatedOpacity(
      duration: const Duration(milliseconds: AppConstants.animationNormal),
      opacity: 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(color: borderColor, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: theme.scaffoldBackgroundColor,
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: theme.scaffoldBackgroundColor,
                      child: Icon(
                        Icons.image_not_supported_rounded, 
                        size: 32, 
                        color: theme.hintColor,
                      ),
                    ),
                  ),
                  // Duration badge (minimalist black block)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(AppConstants.radiusSmall - 4),
                      ),
                      child: Text(
                        Validators.formatDuration(video.duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
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
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppConstants.spaceSmall),

                  // Channel Name
                  Row(
                    children: [
                      Icon(
                        Icons.portrait_rounded,
                        size: 16,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ?? theme.hintColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          video.author,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spaceSmall + 2),

                  Divider(color: borderColor),
                  const SizedBox(height: AppConstants.spaceSmall),

                  // File Size Badge
                  Consumer<VideoProvider>(
                    builder: (context, provider, child) {
                      final selectedStream =
                          provider.availableStreams[provider.selectedQuality];
                      final fileSize = selectedStream?.size.totalBytes ?? 0;
                      final fileSizeMB = (fileSize / (1024 * 1024))
                          .toStringAsFixed(1);

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Estimated Size',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppConstants.radiusSmall - 2),
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.data_usage_rounded,
                                  size: 13,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$fileSizeMB MB',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
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
