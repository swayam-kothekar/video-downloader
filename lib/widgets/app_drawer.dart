import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/video_provider.dart';
import '../screens/downloads_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/home_screen.dart';
import '../screens/about_screen.dart';
import '../utils/constants.dart';

class AppDrawer extends StatelessWidget {
  final String activeRoute;

  const AppDrawer({
    super.key,
    required this.activeRoute,
  });



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final videoProvider = Provider.of<VideoProvider>(context);

    return Drawer(
      backgroundColor: isDark ? AppConstants.background : const Color(0xFFFAFAFA),
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(AppConstants.radiusLarge),
          bottomRight: Radius.circular(AppConstants.radiusLarge),
        ),
      ),
      child: Column(
        children: [
            // Drawer Header (Premium Gradient & Glow)
            _buildDrawerHeader(context),

            // Navigation Items
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceSmall,
                  vertical: AppConstants.spaceMedium,
                ),
                children: [
                  _buildDrawerTile(
                    context,
                    icon: Icons.download_rounded,
                    title: 'Downloader',
                    isActive: activeRoute == 'downloader',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      if (activeRoute != 'downloader') {
                        // If not on downloader, pop back to home (root)
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  _buildDrawerTile(
                    context,
                    icon: Icons.history_rounded,
                    title: 'Downloads History',
                    isActive: activeRoute == 'downloads',
                    trailing: videoProvider.activeDownloadsCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppConstants.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              videoProvider.activeDownloadsCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      if (activeRoute != 'downloads') {
                        Navigator.push(
                          context,
                          SmoothPageRoute(child: const DownloadsScreen()),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  _buildDrawerTile(
                    context,
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    isActive: activeRoute == 'settings',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      if (activeRoute != 'settings') {
                        Navigator.push(
                          context,
                          SmoothPageRoute(child: const SettingsScreen()),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  _buildThemeToggleTile(context, themeProvider),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppConstants.spaceMedium,
                      horizontal: AppConstants.spaceSmall,
                    ),
                    child: Divider(
                      color: isDark ? AppConstants.border : Colors.grey[200],
                      height: 1,
                    ),
                  ),

                  _buildDrawerTile(
                    context,
                    icon: Icons.info_outline_rounded,
                    title: 'About App',
                    isActive: activeRoute == 'about',
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      if (activeRoute != 'about') {
                        Navigator.push(
                          context,
                          SmoothPageRoute(child: const AboutScreen()),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            // Footer Version Info
            Padding(
              padding: const EdgeInsets.all(AppConstants.spaceMedium),
              child: Text(
                'v${AppConstants.appVersion}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: AppConstants.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppConstants.spaceLarge,
        bottom: AppConstants.spaceLarge,
        left: AppConstants.spaceMedium,
        right: AppConstants.spaceMedium,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDark ? const Color(0xFF18182B) : const Color(0xFFE6E9F7),
            isDark ? AppConstants.background : const Color(0xFFFAFAFA),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Glowing logo icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppConstants.primary.withValues(alpha: isDark ? 0.3 : 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spaceMedium),
          
          // App Title
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
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
          const SizedBox(height: 4),
          Text(
            'Fast & private media downloader',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 11,
              color: AppConstants.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isActive,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color activeColor = AppConstants.primary;
    final Color inactiveColor = theme.textTheme.bodyMedium?.color ?? AppConstants.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: isActive 
            ? activeColor.withValues(alpha: isDark ? 0.1 : 0.07) 
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spaceMedium,
          vertical: 2,
        ),
        leading: Icon(
          icon,
          color: isActive ? activeColor : inactiveColor.withValues(alpha: 0.8),
          size: 20,
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
            color: isActive ? activeColor : theme.textTheme.bodyLarge?.color,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Widget _buildThemeToggleTile(BuildContext context, ThemeProvider themeProvider) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spaceMedium,
          vertical: 2,
        ),
        leading: Icon(
          themeProvider.isDarkMode
              ? Icons.dark_mode_rounded
              : Icons.light_mode_rounded,
          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
          size: 20,
        ),
        title: Text(
          'Dark Mode',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        trailing: Switch.adaptive(
          value: themeProvider.isDarkMode,
          activeThumbColor: AppConstants.primary,
          activeTrackColor: AppConstants.primary.withValues(alpha: 0.3),
          onChanged: (value) {
            themeProvider.toggleTheme();
          },
        ),
      ),
    );
  }
}
