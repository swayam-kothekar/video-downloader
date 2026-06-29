import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/video_provider.dart';
import '../providers/theme_provider.dart';
import '../models/download_log.dart';
import '../utils/constants.dart';
import '../widgets/download_progress_card.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              isDark ? const Color(0xFF111224) : const Color(0xFFEDF0FA), // premium ambient top glow
              theme.scaffoldBackgroundColor,
            ],
            center: const Alignment(0.0, -0.9),
            radius: 1.3,
          ),
        ),
        child: SafeArea(
          child: Consumer<VideoProvider>(
            builder: (context, provider, child) {
              final hasActiveDownloads = provider.activeDownloads.isNotEmpty;
              final isEmpty = !hasActiveDownloads && provider.downloadLogs.isEmpty;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Minimalist App Bar
                  SliverAppBar(
                    floating: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    systemOverlayStyle: SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
                      systemNavigationBarColor: Colors.black, // Lock navigation bar to black
                      systemNavigationBarIconBrightness: Brightness.light, // Lock navigation bar icons to light
                      systemNavigationBarDividerColor: Colors.transparent,
                      systemNavigationBarContrastEnforced: false,
                    ),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Back',
                    ),
                    title: Text(
                      'Downloads',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: theme.textTheme.displayLarge?.color,
                      ),
                    ),
                    centerTitle: true,
                    actions: [
                      if (provider.downloadLogs.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.delete_sweep_rounded, size: 20, color: AppConstants.error),
                          tooltip: 'Clear History',
                          onPressed: () => _showClearConfirmationDialog(context, provider),
                        ),
                      const SizedBox(width: 8),
                    ],
                  ),

                  // Empty State OR List Content
                  if (isEmpty)
                    _buildEmptyState(context)
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spaceMedium,
                        vertical: AppConstants.spaceSmall,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          const SizedBox(height: AppConstants.spaceSmall),

                          // Active Downloads Section
                          if (hasActiveDownloads) ...[
                            Text(
                              'Active Tasks',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: theme.textTheme.displayLarge?.color ?? (isDark ? Colors.white : Colors.black),
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: AppConstants.spaceSmall + 2),
                            ...provider.activeDownloads.values.toList().reversed.map((download) {
                              final double speedMB = download.speed / (1024 * 1024);
                              final speedText = download.speed > 0
                                  ? '${speedMB.toStringAsFixed(1)} MB/s'
                                  : '0.0 KB/s';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppConstants.spaceMedium),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      download.videoTitle,
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Speed: $speedText',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontSize: 11,
                                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.75) ?? AppConstants.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: AppConstants.spaceSmall),
                                    DownloadProgressCard(
                                      progress: download.progress,
                                      status: download.errorMessage ?? download.status,
                                      showCancel: !download.isMerging,
                                      showPauseResume: !download.isMerging,
                                      isPaused: download.status == 'Paused',
                                      onCancel: () => provider.cancelDownload(download.id),
                                      onPause: () => provider.pauseDownload(download.id),
                                      onResume: () {
                                        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
                                        provider.resumeDownload(
                                          download.id,
                                          wifiOnly: themeProvider.wifiOnly,
                                          subtitleDownload: themeProvider.subtitleDownload,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: AppConstants.spaceLarge),
                          ],

                          // History Section
                          if (provider.downloadLogs.isNotEmpty) ...[
                            Text(
                              'Task History',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: theme.textTheme.displayLarge?.color ?? (isDark ? Colors.white : Colors.black),
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: AppConstants.spaceMedium),
                            ...provider.downloadLogs.map(
                              (log) => _buildHistoryItem(context, log, provider),
                            ),
                          ],

                          // Footer note for storage location
                          const SizedBox(height: AppConstants.spaceSmall),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceMedium, vertical: AppConstants.spaceSmall),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 0.5),
                                    child: Icon(
                                      Icons.folder_open_rounded,
                                      size: 14,
                                      color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.85) ?? (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Videos are saved in your device\'s Downloads folder',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.85) ?? (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppConstants.spaceMedium),
                        ]),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: (MediaQuery.of(context).padding.bottom > 0 && MediaQuery.of(context).viewInsets.bottom == 0)
          ? Container(
              color: Colors.black,
              height: MediaQuery.of(context).padding.bottom,
            )
          : null,
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = isDark ? AppConstants.border : const Color(0xFFE4E4E7);

    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spaceLarge),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceLarge, vertical: 40),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15), width: 1),
                  ),
                  child: Icon(
                    Icons.cloud_download_outlined,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppConstants.spaceLarge),
                Text(
                  'No recent downloads found',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: AppConstants.spaceSmall),
                Text(
                  'Your downloaded videos will appear here. Start downloading your favorite YouTube content!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    height: 1.5,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6) ?? AppConstants.textSecondary,
                  ),
                ),
                const SizedBox(height: AppConstants.spaceLarge + 8),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('Search & Download'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceLarge, vertical: AppConstants.spaceMedium),
                    elevation: 0,
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildHistoryItem(BuildContext context, DownloadLog log, VideoProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppConstants.border : const Color(0xFFE4E4E7);
    final statusColor = log.isSuccess ? AppConstants.success : AppConstants.error;
    final dateFormatter = DateFormat('MMM d, yyyy • hh:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceMedium),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        child: Container(
          // Subtle color bar on the left to indicate success/error
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: statusColor, width: 4),
            ),
          ),
          padding: const EdgeInsets.all(AppConstants.spaceMedium),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.videoTitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppConstants.spaceSmall + 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: log.isSuccess 
                                ? AppConstants.success.withValues(alpha: 0.08)
                                : AppConstants.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                            border: Border.all(
                              color: log.isSuccess 
                                  ? AppConstants.success.withValues(alpha: 0.15)
                                  : AppConstants.error.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Text(
                            log.isSuccess ? 'Success' : 'Failed',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: statusColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        Expanded(
                          child: Text(
                            dateFormatter.format(log.downloadDate),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5) ?? theme.hintColor,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (!log.isSuccess && log.errorMessage != null) ...[
                      const SizedBox(height: AppConstants.spaceSmall + 2),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppConstants.error.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                          border: Border.all(color: AppConstants.error.withValues(alpha: 0.1), width: 1),
                        ),
                        child: Text(
                          log.errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppConstants.error,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.spaceSmall),
              // Action Buttons
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                tooltip: 'Remove from History',
                color: AppConstants.error.withValues(alpha: 0.7),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
                onPressed: () {
                  provider.deleteDownloadLog(log);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearConfirmationDialog(BuildContext context, VideoProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardTheme.color ?? theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          side: BorderSide(color: isDark ? AppConstants.border : const Color(0xFFE4E4E7), width: 1),
        ),
        title: Text(
          'Clear History?',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Text(
          'This will permanently clear all your download logs. The downloaded files themselves will not be affected.',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ?? theme.hintColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              provider.clearDownloadLogs();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.error,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusSmall + 2),
              ),
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
