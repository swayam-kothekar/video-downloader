import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _openUrl(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $urlString');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open link: $urlString'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppConstants.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('About'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              isDark ? const Color(0xFF111224) : const Color(0xFFEDF0FA),
              theme.scaffoldBackgroundColor,
            ],
            center: const Alignment(0.0, -0.9),
            radius: 1.3,
          ),
        ),
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceMedium),
            children: [
              const SizedBox(height: AppConstants.spaceLarge),

              // App Logo Card
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppConstants.primary.withValues(alpha: isDark ? 0.3 : 0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConstants.spaceMedium),
                    
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                        children: [
                          TextSpan(
                            text: 'Video',
                            style: TextStyle(
                              color: theme.textTheme.displayLarge?.color,
                            ),
                          ),
                          const TextSpan(
                            text: 'Downloader',
                            style: TextStyle(color: AppConstants.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Version ${AppConstants.appVersion}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppConstants.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppConstants.spaceXLarge),

              // Description (flat centered text block)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceLarge,
                  vertical: AppConstants.spaceSmall,
                ),
                child: Text(
                  'Video Downloader is an open-source utility for Android that simplifies video and audio acquisition from YouTube. Built with Flutter, it focuses on high performance, beautiful aesthetics, and complete user privacy with zero tracking.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    fontSize: 13.5,
                    color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.85),
                  ),
                ),
              ),

              const SizedBox(height: AppConstants.spaceLarge),

              // Divider between description and info list
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceSmall),
                child: Divider(
                  color: isDark ? AppConstants.border : Colors.grey[200],
                  height: 1,
                ),
              ),

              const SizedBox(height: AppConstants.spaceLarge),

              // Information section header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceSmall),
                child: Text(
                  'INFORMATION',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppConstants.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spaceSmall),

              // Flat Info list rows
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceSmall),
                child: Column(
                  children: [
                    _buildFlatInfoRow(
                      context,
                      label: 'Developer',
                      value: 'Swayam Kothekar',
                    ),
                    _buildFlatDivider(isDark),
                    _buildFlatInfoRow(
                      context,
                      label: 'Tech Stack',
                      value: 'Flutter, Dart, FFmpeg',
                    ),
                    _buildFlatDivider(isDark),
                    _buildFlatInfoRow(
                      context,
                      label: 'License',
                      value: 'MIT License',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppConstants.spaceXLarge),

              // External Links
              _buildCard(
                context,
                child: Column(
                  children: [
                    ListTile(
                      tileColor: Colors.transparent,
                      leading: const Icon(Icons.code_rounded, color: AppConstants.primary),
                      title: const Text('Source Code (GitHub)'),
                      subtitle: const Text('View and contribute to the repository'),
                      trailing: const Icon(Icons.launch_rounded, size: 16),
                      onTap: () => _openUrl(context, 'https://github.com/swayam-kothekar/video-downloader'),
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      endIndent: 16,
                      color: isDark ? AppConstants.border : Colors.grey[200],
                    ),
                    ListTile(
                      tileColor: Colors.transparent,
                      leading: const Icon(Icons.bug_report_rounded, color: AppConstants.primary),
                      title: const Text('Submit Feedback / Issues'),
                      subtitle: const Text('Report bugs or request new features'),
                      trailing: const Icon(Icons.launch_rounded, size: 16),
                      onTap: () => _openUrl(context, 'https://github.com/swayam-kothekar/video-downloader/issues'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppConstants.spaceXLarge),

              // Footer copyright info
              Center(
                child: Text(
                  '© 2026 Swayam Kothekar. All rights reserved.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 11,
                    color: AppConstants.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        side: BorderSide(
          color: isDark ? AppConstants.border : Colors.grey[200]!,
          width: 1,
        ),
      ),
      color: isDark ? AppConstants.surface : Colors.white,
      child: child,
    );
  }

  Widget _buildFlatInfoRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppConstants.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlatDivider(bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? AppConstants.border : Colors.grey[200],
    );
  }
}
