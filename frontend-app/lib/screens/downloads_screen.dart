import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/video_provider.dart';
import '../models/download_log.dart';
import '../utils/constants.dart';
import '../widgets/download_progress_card.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppConstants.backgroundGradient,
        ),
        child: SafeArea(
          child: Consumer<VideoProvider>(
            builder: (context, provider, child) {
              return CustomScrollView(
                slivers: [
                  // App Bar
                  SliverAppBar(
                    floating: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: ShaderMask(
                      shaderCallback: (bounds) =>
                          AppConstants.primaryGradient.createShader(bounds),
                      child: const Text(
                        'Downloads',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    centerTitle: true,
                  ),

                  // Content
                  SliverPadding(
                    padding: const EdgeInsets.all(AppConstants.spaceLarge),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Active Download
                        if (provider.state == VideoState.downloading) ...[
                          Text(
                            'Current Download',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: AppConstants.spaceSmall),
                          if (provider.currentVideo != null) ...[
                            Text(
                              provider.currentVideo!.title,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: AppConstants.primaryPurple,
                                    fontWeight: FontWeight.w500,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppConstants.spaceMedium),
                          ],
                          DownloadProgressCard(
                            progress: provider.downloadProgress,
                            status: provider.downloadStatus,
                            onCancel: () => provider.cancelDownload(),
                          ),
                          const SizedBox(height: AppConstants.spaceLarge),
                        ],

                        // Download Complete
                        if (provider.state == VideoState.downloaded) ...[
                          _buildSuccessCard(context),
                          const SizedBox(height: AppConstants.spaceLarge),
                        ],

                        // Error State
                        if (provider.state == VideoState.error &&
                            provider.errorMessage != null) ...[
                          _buildErrorCard(context, provider.errorMessage!),
                          const SizedBox(height: AppConstants.spaceLarge),
                        ],

                        // Download History
                        if (provider.downloadLogs.isNotEmpty) ...[
                          Text(
                            'Recent Downloads',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: AppConstants.spaceMedium),
                          ...provider.downloadLogs.map(
                            (log) => _buildHistoryItem(context, log),
                          ),
                        ],

                        // No Downloads
                        if (provider.state != VideoState.downloading &&
                            provider.state != VideoState.downloaded &&
                            provider.downloadLogs.isEmpty) ...[
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 100),
                                Icon(
                                  Icons.download_outlined,
                                  size: 80,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                const SizedBox(
                                  height: AppConstants.spaceMedium,
                                ),
                                Text(
                                  'No downloads yet',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceLarge),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: Colors.greenAccent),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 32),
          const SizedBox(width: AppConstants.spaceMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Download Complete!',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.greenAccent),
                ),
                const SizedBox(height: 4),
                Text(
                  'Video saved to Downloads folder',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String errorMessage) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceLarge),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.redAccent, size: 32),
          const SizedBox(width: AppConstants.spaceMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Download Failed',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.redAccent),
                ),
                const SizedBox(height: 4),
                Text(
                  errorMessage,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, DownloadLog log) {
    final dateFormatter = DateFormat('MMM d, HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceMedium),
      padding: const EdgeInsets.all(AppConstants.spaceMedium),
      decoration: BoxDecoration(
        color: AppConstants.darkCard.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: log.isSuccess
              ? Colors.greenAccent.withOpacity(0.3)
              : Colors.redAccent.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            log.isSuccess ? Icons.check_circle : Icons.error,
            color: log.isSuccess ? Colors.greenAccent : Colors.redAccent,
            size: 24,
          ),
          const SizedBox(width: AppConstants.spaceMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.videoTitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      log.quality,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppConstants.primaryPurple,
                      ),
                    ),
                    Text(
                      ' • ${dateFormatter.format(log.downloadDate)}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                    ),
                  ],
                ),
                if (!log.isSuccess && log.errorMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Error: ${log.errorMessage}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.redAccent),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
