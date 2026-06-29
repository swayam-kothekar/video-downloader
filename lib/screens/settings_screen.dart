import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _cacheSizeMB = 0.0;
  bool _isLoadingCacheSize = true;

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    setState(() {
      _isLoadingCacheSize = true;
    });

    try {
      final storage = StorageService();
      final tempPath = await storage.getTempDownloadDirectory();
      final tempDir = Directory(tempPath);
      double totalSize = 0;

      if (await tempDir.exists()) {
        final List<FileSystemEntity> files = tempDir.listSync(recursive: true);
        for (final FileSystemEntity file in files) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      }

      if (mounted) {
        setState(() {
          _cacheSizeMB = totalSize / (1024 * 1024);
          _isLoadingCacheSize = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cacheSizeMB = 0.0;
          _isLoadingCacheSize = false;
        });
      }
    }
  }

  Future<void> _clearCache() async {
    try {
      final storage = StorageService();
      final tempPath = await storage.getTempDownloadDirectory();
      final tempDir = Directory(tempPath);

      if (await tempDir.exists()) {
        final List<FileSystemEntity> files = tempDir.listSync(recursive: true);
        for (final FileSystemEntity file in files) {
          if (file is File) {
            await file.delete();
          }
        }
      }

      await _calculateCacheSize();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 12),
                Text(
                  'Temporary cache cleared successfully',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppConstants.success,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            margin: const EdgeInsets.all(AppConstants.spaceMedium),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to clear cache: ${e.toString()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppConstants.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            ),
            margin: const EdgeInsets.all(AppConstants.spaceMedium),
          ),
        );
      }
    }
  }

  Future<void> _openUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $urlString');
      }
    } catch (e) {
      if (mounted) {
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

  void _showThemeSelector(BuildContext context, ThemeProvider themeProvider) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.brightness == Brightness.dark
              ? AppConstants.surface
              : Colors.white,
          title: Text(
            'Choose Theme',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            side: BorderSide(
              color: theme.brightness == Brightness.dark
                  ? AppConstants.border
                  : Colors.grey[200]!,
            ),
          ),
          content: RadioGroup<ThemeMode>(
            groupValue: themeProvider.themeMode,
            onChanged: (val) {
              if (val != null) {
                themeProvider.setThemeMode(val);
                Navigator.pop(context);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildThemeRadioOption(
                  context,
                  'System Default',
                  ThemeMode.system,
                  themeProvider,
                ),
                _buildThemeRadioOption(
                  context,
                  'Light Theme',
                  ThemeMode.light,
                  themeProvider,
                ),
                _buildThemeRadioOption(
                  context,
                  'Dark Theme',
                  ThemeMode.dark,
                  themeProvider,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeRadioOption(
    BuildContext context,
    String label,
    ThemeMode mode,
    ThemeProvider themeProvider,
  ) {
    final theme = Theme.of(context);
    final isSelected = themeProvider.themeMode == mode;

    return InkWell(
      onTap: () {
        themeProvider.setThemeMode(mode);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Radio<ThemeMode>(value: mode, activeColor: AppConstants.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? AppConstants.primary
                    : theme.textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Dynamic theme status text
    String themeText = 'Dark';
    if (themeProvider.themeMode == ThemeMode.light) {
      themeText = 'Light';
    } else if (themeProvider.themeMode == ThemeMode.system) {
      themeText = 'System Default';
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
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
            padding: const EdgeInsets.all(AppConstants.spaceMedium),
            children: [
              // Section: General Settings
              _buildSectionHeader(context, 'General'),
              _buildSettingCard(
                context,
                children: [
                  _buildSettingTile(
                    context,
                    icon: Icons.palette_rounded,
                    title: 'App Theme',
                    subtitle: themeText,
                    onTap: () => _showThemeSelector(context, themeProvider),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spaceLarge),

              // Section: Preferences
              _buildSectionHeader(context, 'Preferences'),
              _buildSettingCard(
                context,
                children: [
                  _buildSettingSwitchTile(
                    context,
                    icon: Icons.wifi_rounded,
                    title: 'Wi-Fi Only Mode',
                    subtitle: 'Pause downloads when using cellular networks',
                    value: themeProvider.wifiOnly,
                    onChanged: themeProvider.setWifiOnly,
                  ),
                  _buildDivider(),
                  _buildSettingSwitchTile(
                    context,
                    icon: Icons.subtitles_rounded,
                    title: 'Download Subtitles',
                    subtitle: 'Fetch closed captions alongside video media',
                    value: themeProvider.subtitleDownload,
                    onChanged: themeProvider.setSubtitleDownload,
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spaceLarge),

              // Section: Maintenance
              _buildSectionHeader(context, 'Maintenance'),
              _buildSettingCard(
                context,
                children: [
                  ListTile(
                    tileColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spaceMedium,
                      vertical: 6,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppConstants.primary.withValues(
                          alpha: isDark ? 0.08 : 0.05,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.cleaning_services_rounded,
                        color: AppConstants.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Clear Temporary Cache',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    subtitle: Text(
                      _isLoadingCacheSize
                          ? 'Calculating...'
                          : 'Cleans up partial or failed temp logs (${_cacheSizeMB.toStringAsFixed(2)} MB)',
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                    trailing: TextButton(
                      onPressed: _isLoadingCacheSize ? null : _clearCache,
                      style: TextButton.styleFrom(
                        foregroundColor: AppConstants.primary,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      child: const Text('CLEAR'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spaceLarge),

              // Section: About
              _buildSectionHeader(context, 'About & Help'),
              _buildSettingCard(
                context,
                children: [
                  _buildSettingTile(
                    context,
                    icon: Icons.code_rounded,
                    title: 'GitHub Repository',
                    subtitle: 'View source code & contributions',
                    onTap: () => _openUrl(
                      'https://github.com/swayam-kothekar/video-downloader',
                    ),
                  ),
                  _buildDivider(),
                  _buildSettingTile(
                    context,
                    icon: Icons.bug_report_rounded,
                    title: 'Report an Issue',
                    subtitle: 'Submit bugs or request features',
                    onTap: () => _openUrl(
                      'https://github.com/swayam-kothekar/video-downloader/issues',
                    ),
                  ),
                  _buildDivider(),
                  ListTile(
                    tileColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spaceMedium,
                      vertical: 4,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppConstants.secondary.withValues(
                          alpha: isDark ? 0.08 : 0.05,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.info_outline_rounded,
                        color: AppConstants.secondary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'App Version',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    subtitle: const Text(
                      '${AppConstants.appVersion} (Stable)',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    String? infoText,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        left: AppConstants.spaceSmall,
        bottom: AppConstants.spaceSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppConstants.primary,
            ),
          ),
          if (infoText != null) ...[
            const SizedBox(height: 2),
            Text(
              infoText,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 11,
                color: AppConstants.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
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
      child: Column(children: children),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      tileColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spaceMedium,
        vertical: 4,
      ),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppConstants.primary.withValues(alpha: isDark ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppConstants.primary, size: 20),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppConstants.textMuted,
        size: 20,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSettingSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      tileColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spaceMedium,
        vertical: 4,
      ),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppConstants.primary.withValues(alpha: isDark ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppConstants.primary, size: 20),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
      ),
      trailing: Switch.adaptive(
        value: value,
        activeThumbColor: AppConstants.primary,
        activeTrackColor: AppConstants.primary.withValues(alpha: 0.3),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 64, endIndent: 16);
  }
}
