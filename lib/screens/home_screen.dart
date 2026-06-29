import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../providers/video_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/validators.dart';
import '../utils/constants.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/video_info_card.dart';
import 'downloads_screen.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  bool _isValidUrl = false;

  @override
  void initState() {
    super.initState();
    _setupShareListener();

    // Remove the splash screen once the first frame is painted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
      FlutterNativeSplash.remove();
    });
  }

  void _setupShareListener() {
    const platform = MethodChannel('com.example.video_downloader/share');

    void handleUrl(String? sharedUrl) {
      if (sharedUrl != null && sharedUrl.isNotEmpty && mounted) {
        setState(() {
          _urlController.text = sharedUrl;
          _isValidUrl = Validators.isValidYouTubeUrl(sharedUrl);
        });

        if (_isValidUrl) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final provider = Provider.of<VideoProvider>(context, listen: false);
            final themeProvider = Provider.of<ThemeProvider>(
              context,
              listen: false,
            );
            provider.fetchVideoInfo(
              sharedUrl,
              defaultQuality: themeProvider.defaultQuality,
            );
          });
        }
      }
    }

    platform.setMethodCallHandler((call) async {
      if (call.method == 'onSharedUrl') {
        final String? sharedUrl = call.arguments as String?;
        handleUrl(sharedUrl);
      }
    });

    // Check for initial shared URL when app is opened via share target
    platform.invokeMethod<String>('getSharedUrl').then((sharedUrl) {
      handleUrl(sharedUrl);
    }).catchError((_) {});
  }

  VideoProvider? _videoProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<VideoProvider>(context);
    if (_videoProvider != provider) {
      _videoProvider?.removeListener(_onProviderStateChanged);
      _videoProvider = provider;
      _videoProvider?.addListener(_onProviderStateChanged);
    }
    // Precache the drawer logo so it's ready when drawer first opens
    precacheImage(const AssetImage('assets/images/logo.png'), context);
  }

  @override
  void dispose() {
    _videoProvider?.removeListener(_onProviderStateChanged);
    _urlController.dispose();
    super.dispose();
  }

  void _onProviderStateChanged() {
    if (!mounted) return;
    final provider = _videoProvider;
    if (provider == null) return;

    if (provider.state == VideoState.error && provider.errorMessage != null) {
      _showErrorSnackBar(context, provider.errorMessage!);
      provider.clearError();
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
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
                message,
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
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        margin: const EdgeInsets.all(AppConstants.spaceMedium),
      ),
    );
  }

  void _validateUrl(String url) {
    setState(() {
      _isValidUrl = Validators.isValidYouTubeUrl(url);
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    if (data?.text != null) {
      _urlController.text = data!.text!;
      _validateUrl(data.text!);
    }
  }

  void _clearUrl() {
    _urlController.clear();
    setState(() {
      _isValidUrl = false;
    });
    Provider.of<VideoProvider>(context, listen: false).reset();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        drawer: const RepaintBoundary(
          child: AppDrawer(activeRoute: 'downloader'),
        ),
        body: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  isDark
                      ? const Color(0xFF111224)
                      : const Color(0xFFEDF0FA), // premium ambient top glow
                  theme.scaffoldBackgroundColor,
                ],
                center: const Alignment(0.0, -0.9),
                radius: 1.3,
              ),
            ),
            child: SafeArea(
              child: Consumer<VideoProvider>(
                builder: (context, provider, child) {
                  // Calculate responsive top padding to center search inputs vertically when empty (accounting for HeroSection)
                  final bool showCentered =
                      provider.currentVideo == null &&
                      provider.state != VideoState.loading;
                  final double rawPadding =
                      (MediaQuery.of(context).size.height - 440) / 2 -
                      MediaQuery.of(context).padding.top -
                      56;
                  final double topPadding = showCentered
                      ? (rawPadding > 0 ? rawPadding : 0.0)
                      : 0.0;

                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // Minimal App Bar
                      SliverAppBar(
                        floating: true,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        leading: Builder(
                          builder: (context) => IconButton(
                            icon: Icon(
                              Icons.menu_rounded,
                              color: theme.textTheme.bodyMedium?.color,
                              size: 20,
                            ),
                            onPressed: () {
                              Scaffold.of(context).openDrawer();
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                            tooltip: 'Open Menu',
                          ),
                        ),
                        systemOverlayStyle: SystemUiOverlayStyle(
                          statusBarColor: Colors.transparent,
                          statusBarIconBrightness: isDark
                              ? Brightness.light
                              : Brightness.dark,
                          statusBarBrightness: isDark
                              ? Brightness.dark
                              : Brightness.light,
                          systemStatusBarContrastEnforced:
                              false, // Prevent Android from adding a dark scrim in light mode
                          systemNavigationBarColor:
                              Colors.black, // Lock navigation bar to black
                          systemNavigationBarIconBrightness: Brightness
                              .light, // Lock navigation bar icons to light
                          systemNavigationBarContrastEnforced: false,
                        ),
                        title: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 16,
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
                        centerTitle: true,
                        actions: [
                          IconButton(
                            icon: Badge(
                              isLabelVisible: provider.activeDownloadsCount > 0,
                              largeSize: 12,
                              label: Text(
                                provider.activeDownloadsCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              child: Icon(
                                Icons.history_rounded,
                                color: theme.textTheme.bodyMedium?.color,
                                size: 20,
                              ),
                            ),
                            onPressed: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              Navigator.push(
                                context,
                                SmoothPageRoute(child: const DownloadsScreen()),
                              );
                            },
                            tooltip: 'Downloads History',
                          ),
                          const SizedBox(width: AppConstants.spaceSmall),
                        ],
                      ),

                      // Space animator to center inputs smoothly
                      SliverToBoxAdapter(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          curve: const Cubic(
                            0.16,
                            1,
                            0.3,
                            1,
                          ), // easeOutExpo for super smooth layout shift
                          height: topPadding,
                        ),
                      ),

                      // Main Content List
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spaceMedium,
                          vertical: AppConstants.spaceSmall,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            const SizedBox(height: AppConstants.spaceSmall),

                            // Premium Hero Section Widget (with smooth height/opacity transitions)
                            AnimatedSize(
                              duration: const Duration(milliseconds: 600),
                              curve: const Cubic(0.16, 1, 0.3, 1),
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                                opacity: showCentered ? 1.0 : 0.0,
                                child: showCentered
                                    ? const HeroSection()
                                    : const SizedBox.shrink(),
                              ),
                            ),

                            // URL Input Field
                            CustomTextField(
                              controller: _urlController,
                              hintText: 'Paste YouTube video link here...',
                              isValid: _isValidUrl,
                              errorText: null, // Shown via SnackBar instead
                              onChanged: _validateUrl,
                              onPaste: _pasteFromClipboard,
                              onClear: _clearUrl,
                            ),
                            const SizedBox(height: AppConstants.spaceMedium),

                            // Analyze URL Button
                            _buildGetInfoButton(provider),

                            const SizedBox(height: AppConstants.spaceLarge),
                            _buildStatefulContent(provider, context),
                          ]),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
    );
  }

  Widget _buildGetInfoButton(VideoProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool isLoading = provider.state == VideoState.loading;
    final bool isEnabled = _isValidUrl && !isLoading;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isEnabled && !isLoading
            ? () {
                FocusManager.instance.primaryFocus?.unfocus();
                final themeProvider = Provider.of<ThemeProvider>(
                  context,
                  listen: false,
                );
                provider.fetchVideoInfo(
                  _urlController.text,
                  defaultQuality: themeProvider.defaultQuality,
                );
              }
            : null, // Disabled when loading or when URL is invalid (greys out!)
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled
              ? AppConstants.primary
              : (isDark ? AppConstants.surface : Colors.white),
          foregroundColor: isEnabled ? Colors.white : AppConstants.textMuted,
          disabledBackgroundColor: isDark
              ? AppConstants.surface
              : Colors.grey[200],
          disabledForegroundColor: AppConstants.textMuted,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            side: BorderSide(
              color: isEnabled
                  ? Colors.transparent
                  : (isDark ? AppConstants.border : const Color(0xFFE4E4E7)),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppConstants.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spaceSmall),
              const Text(
                'Searching...',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ] else ...[
              Icon(
                Icons.search_rounded,
                color: isEnabled ? Colors.white : AppConstants.textMuted,
                size: 16,
              ),
              const SizedBox(width: AppConstants.spaceSmall),
              const Text(
                'Search Video',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }



  void _showWifiOnlyWarningDialog(
    BuildContext context,
    ThemeProvider themeProvider,
    VideoProvider provider,
  ) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.brightness == Brightness.dark
              ? AppConstants.surface
              : Colors.white,
          title: Row(
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: AppConstants.warning,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Wi-Fi Only Enabled',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            side: BorderSide(
              color: theme.brightness == Brightness.dark
                  ? AppConstants.border
                  : Colors.grey[200]!,
            ),
          ),
          content: Text(
            'You are trying to download using cellular data, but Wi-Fi Only Mode is active. Would you like to disable it and download now, or cancel?',
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                themeProvider.setWifiOnly(false); // Disable Wi-Fi only mode
                _startDownloadProcess(context, themeProvider, provider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Disable & Download'),
            ),
          ],
        );
      },
    );
  }

  void _startDownloadProcess(
    BuildContext context,
    ThemeProvider themeProvider,
    VideoProvider provider,
  ) {
    provider.downloadVideo(
      wifiOnly: themeProvider.wifiOnly,
      subtitleDownload: themeProvider.subtitleDownload,
    );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: AppConstants.spaceMedium),
            Text(
              'Initializing download...',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: isDark ? AppConstants.surface : Colors.grey[900],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          side: BorderSide(
            color: isDark ? AppConstants.border : Colors.transparent,
            width: 1,
          ),
        ),
        margin: const EdgeInsets.all(AppConstants.spaceMedium),
      ),
    );

    Navigator.push(context, SmoothPageRoute(child: const DownloadsScreen()));
  }

  Widget _buildDownloadButton(VideoProvider provider, BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDownloading = provider.isCurrentlySelectedVideoDownloading;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isDownloading
            ? null
            : () async {
                FocusManager.instance.primaryFocus?.unfocus();
                final themeProvider = Provider.of<ThemeProvider>(
                  context,
                  listen: false,
                );

                if (themeProvider.wifiOnly) {
                  final result = await Connectivity().checkConnectivity();
                  final isMobile = result == ConnectivityResult.mobile;
                  if (isMobile) {
                    if (context.mounted) {
                      _showWifiOnlyWarningDialog(
                        context,
                        themeProvider,
                        provider,
                      );
                    }
                  } else {
                    if (context.mounted) {
                      _startDownloadProcess(context, themeProvider, provider);
                    }
                  }
                } else {
                  _startDownloadProcess(context, themeProvider, provider);
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: isDownloading
              ? (isDark ? AppConstants.surface : Colors.grey[200])
              : AppConstants.primary,
          foregroundColor: isDownloading
              ? AppConstants.textMuted
              : Colors.white,
          disabledBackgroundColor: isDark
              ? AppConstants.surface
              : Colors.grey[200],
          disabledForegroundColor: AppConstants.textMuted,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            side: isDownloading
                ? BorderSide(
                    color: isDark
                        ? AppConstants.border
                        : const Color(0xFFE4E4E7),
                  )
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDownloading
                  ? Icons.hourglass_bottom_rounded
                  : Icons.arrow_downward_rounded,
              color: isDownloading ? AppConstants.textMuted : Colors.white,
              size: 16,
            ),
            const SizedBox(width: AppConstants.spaceSmall),
            Text(
              isDownloading ? 'Download Active...' : 'Start Download',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatefulContent(VideoProvider provider, BuildContext context) {
    Widget child;
    if (provider.state == VideoState.loading) {
      child = const KeyedSubtree(
        key: ValueKey('loading'),
        child: VideoInfoSkeleton(),
      );
    } else if (provider.currentVideo != null) {
      child = KeyedSubtree(
        key: const ValueKey('loaded'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VideoInfoCard(video: provider.currentVideo!),
            const SizedBox(height: AppConstants.spaceLarge),
            _buildDownloadButton(provider, context),
          ],
        ),
      );
    } else {
      child = const SizedBox.shrink(key: ValueKey('empty'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      reverseDuration: const Duration(milliseconds: 400),
      switchInCurve: const Cubic(0.16, 1, 0.3, 1), // easeOutExpo
      switchOutCurve: const Cubic(0.16, 1, 0.3, 1).flipped,
      transitionBuilder: (Widget child, Animation<double> animation) {
        final slideAnimation =
            Tween<Offset>(
              begin: const Offset(0.0, 0.05), // subtle slide up
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Cubic(0.16, 1, 0.3, 1),
              ),
            );

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slideAnimation, child: child),
        );
      },
      child: child,
    );
  }

  Future<void> _checkForUpdates() async {
    final updateService = UpdateService();
    final updateInfo = await updateService.checkForUpdates();
    if (updateInfo != null && mounted) {
      _showUpdateDialog(context, updateInfo);
    }
  }

  void _showUpdateDialog(BuildContext context, AppUpdateInfo updateInfo) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? AppConstants.surface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            side: BorderSide(
              color: isDark ? AppConstants.border : Colors.grey[200]!,
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppConstants.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  color: AppConstants.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'New Update Available',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A new version (${updateInfo.latestVersion}) is available. You are currently on v${AppConstants.appVersion}.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Release Notes:',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppConstants.background : Colors.grey[50],
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusMedium,
                  ),
                  border: Border.all(
                    color: isDark ? AppConstants.border : Colors.grey[200]!,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    updateInfo.releaseNotes,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Later',
                style: TextStyle(
                  color: isDark ? AppConstants.textSecondary : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final url = Uri.parse(updateInfo.releaseUrl);
                try {
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  // Ignore launch errors
                }
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusMedium,
                  ),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Update Now',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Custom Shimmer Horizontal Swipe Animation Wrapper (0 third party dependencies)
class ShimmerLoading extends StatefulWidget {
  final Widget child;

  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Make shimmer colors slightly darker than their container/card background
    // and give them an indigo tint instead of flat grey for a premium, non-grey aesthetic.
    // Dark theme card is #18181B. Base is #0A0B0F, highlight is #13141F.
    // Light theme card is #FFFFFF. Base is #E0E5F0, highlight is #EEF2FA.
    final baseColor = isDark
        ? const Color(0xFF0A0B0F)
        : const Color(0xFFE0E5F0);
    final highlightColor = isDark
        ? const Color(0xFF13141F)
        : const Color(0xFFEEF2FA);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.15, 0.5, 0.85],
              // Strictly left to right horizontal sweep
              begin: Alignment(-2.0 + _controller.value * 4.0, 0.0),
              end: Alignment(-0.5 + _controller.value * 4.0, 0.0),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

// Elegant Video Card + Controls Skeleton (mirrors real layouts)
class VideoInfoSkeleton extends StatelessWidget {
  const VideoInfoSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardTheme.color ?? theme.colorScheme.surface;
    final borderColor = isDark ? AppConstants.border : const Color(0xFFE4E4E7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Static Card Container with Shimmering Children (wrapped together to shimmer in sync)
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium - 1),
            child: ShimmerLoading(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 16:9 Thumbnail block
                  const AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ColoredBox(color: Colors.white),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppConstants.spaceMedium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title details
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: AppConstants.spaceSmall),
                            Container(
                              width: MediaQuery.of(context).size.width * 0.6,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppConstants.spaceMedium),

                        // Author channel details
                        Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 120,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spaceLarge),

        // Shimmering Dropdown Selector Box Skeleton
        Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: ShimmerLoading(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  AppConstants.radiusMedium - 1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spaceMedium),

        // Shimmering Download Action Button Skeleton
        Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: ShimmerLoading(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  AppConstants.radiusMedium - 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Custom page route with extremely smooth page transitions (fade + slide) using Cubic easeOutExpo curves
class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  SmoothPageRoute({required this.child})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => child,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: const Cubic(0.16, 1, 0.3, 1), // easeOutExpo
            reverseCurve: const Cubic(0.16, 1, 0.3, 1).flipped,
          );

          final slideTween = Tween<Offset>(
            begin: const Offset(0.06, 0.0), // subtle modern slide from right
            end: Offset.zero,
          ).animate(curve);

          final fadeTween = Tween<double>(begin: 0.0, end: 1.0).animate(curve);

          return SlideTransition(
            position: slideTween,
            child: FadeTransition(opacity: fadeTween, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 400),
      );
}

// Elegant & Minimalist Hero Branding Section (visible on empty centered home screen)
class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spaceXLarge),
      child: Column(
        children: [
          // Glowing Gradient App Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppConstants.primary.withValues(
                    alpha: isDark ? 0.3 : 0.15,
                  ),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: AppConstants.spaceLarge),

          // Main Header Title
          Text(
            'Search & Download',
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppConstants.spaceSmall),

          // Subtitle / Description
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spaceMedium,
            ),
            child: Text(
              'Fast and reliable YouTube downloads powered by direct stream processing. Free, private, and fully open source.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                height: 1.5,
                color:
                    theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ??
                    AppConstants.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spaceLarge),

          // Modern capability chips
          Wrap(
            spacing: AppConstants.spaceSmall,
            runSpacing: AppConstants.spaceSmall,
            alignment: WrapAlignment.center,
            children: [
              _buildBadge(context, Icons.block_rounded, 'Ad-Free'),
              _buildBadge(context, Icons.shield_outlined, 'Private & Safe'),
              _buildBadge(context, Icons.code_rounded, 'Open Source'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark
        ? AppConstants.primary.withValues(alpha: 0.06)
        : AppConstants.primary.withValues(alpha: 0.04);
    final borderColor = isDark
        ? AppConstants.primary.withValues(alpha: 0.15)
        : AppConstants.primary.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall + 2),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppConstants.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppConstants.primary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
