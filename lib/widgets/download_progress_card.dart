import 'package:flutter/material.dart';
import '../utils/constants.dart';

class DownloadProgressCard extends StatelessWidget {
  final double progress;
  final String status;
  final VoidCallback onCancel;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final bool isPaused;
  final bool showCancel;
  final bool showPauseResume;

  const DownloadProgressCard({
    super.key,
    required this.progress,
    required this.status,
    required this.onCancel,
    this.onPause,
    this.onResume,
    this.isPaused = false,
    this.showCancel = true,
    this.showPauseResume = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppConstants.border : const Color(0xFFE4E4E7);
    final percentage = (progress * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceMedium),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status & Actions (Pause, Resume, Cancel)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  status,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showPauseResume) ...[
                    IconButton(
                      onPressed: isPaused ? onResume : onPause,
                      icon: Icon(
                        isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        size: 20,
                      ),
                      color: isPaused
                          ? theme.colorScheme.primary
                          : (theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6) ?? theme.hintColor),
                      tooltip: isPaused ? 'Resume Download' : 'Pause Download',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      hoverColor: Colors.transparent,
                    ),
                    if (showCancel) const SizedBox(width: 12),
                  ],
                  if (showCancel)
                    IconButton(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6) ?? theme.hintColor,
                      hoverColor: Colors.transparent,
                      tooltip: 'Cancel Download',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMedium),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: theme.scaffoldBackgroundColor,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: AppConstants.spaceSmall + 2),

          // Percentage Text (Right aligned, subtle)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$percentage%',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
