import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/video_provider.dart';
import '../utils/validators.dart';
import '../utils/constants.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/video_info_card.dart';
import 'downloads_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  bool _isValidUrl = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: AppConstants.animationNormal),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _validateUrl(String url) {
    setState(() {
      _isValidUrl = Validators.isValidYouTubeUrl(url);
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
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
  }

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
                    title: ShaderMask(
                      shaderCallback: (bounds) =>
                          AppConstants.primaryGradient.createShader(bounds),
                      child: const Text(
                        AppConstants.appName,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    centerTitle: true,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.download_outlined),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DownloadsScreen(),
                            ),
                          );
                        },
                        tooltip: 'Downloads',
                      ),
                    ],
                  ),

                  // Content
                  SliverPadding(
                    padding: const EdgeInsets.all(AppConstants.spaceLarge),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // URL Input Section
                        CustomTextField(
                          controller: _urlController,
                          hintText: 'Paste YouTube URL here...',
                          isValid: _isValidUrl,
                          errorText: provider.errorMessage,
                          onChanged: _validateUrl,
                          onPaste: _pasteFromClipboard,
                          onClear: _clearUrl,
                        ),
                        const SizedBox(height: AppConstants.spaceLarge),

                        // Search Video Button - Always visible
                        _buildGetInfoButton(provider),

                        // Loading Indicator
                        if (provider.state == VideoState.loading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(AppConstants.spaceLarge),
                              child: CircularProgressIndicator(),
                            ),
                          ),

                        // Video Info Card
                        if (provider.currentVideo != null &&
                            provider.state != VideoState.loading) ...[
                          const SizedBox(height: AppConstants.spaceLarge),
                          VideoInfoCard(video: provider.currentVideo!),
                        ],

                        // Quality Selector and Download Button
                        if (provider.state == VideoState.loaded) ...[
                          const SizedBox(height: AppConstants.spaceLarge),
                          _buildQualitySelector(provider),
                          const SizedBox(height: AppConstants.spaceMedium),
                          _buildDownloadButton(provider, context),
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

  Widget _buildGetInfoButton(VideoProvider provider) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: _isValidUrl ? AppConstants.primaryGradient : null,
        color: !_isValidUrl ? Colors.white24 : null,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        boxShadow: _isValidUrl
            ? [
                BoxShadow(
                  color: AppConstants.primaryPurple.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isValidUrl
              ? () => provider.fetchVideoInfo(_urlController.text)
              : null,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search,
                  color: _isValidUrl ? Colors.white : Colors.white38,
                ),
                const SizedBox(width: AppConstants.spaceSmall),
                Text(
                  'Search Video',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _isValidUrl ? Colors.white : Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQualitySelector(VideoProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spaceMedium,
        vertical: AppConstants.spaceSmall,
      ),
      decoration: BoxDecoration(
        color: AppConstants.darkCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: AppConstants.primaryPurple.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.high_quality, color: AppConstants.primaryPurple),
          const SizedBox(width: AppConstants.spaceMedium),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: provider.selectedQuality,
                dropdownColor: AppConstants.darkCard,
                style: Theme.of(context).textTheme.bodyLarge,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                items: provider.availableQualities.map((quality) {
                  return DropdownMenuItem(value: quality, child: Text(quality));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    provider.selectQuality(value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton(VideoProvider provider, BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppConstants.primaryGradient,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryPurple.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Start download
            provider.downloadVideo();

            // Show snackbar
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Downloading video...'),
                duration: Duration(seconds: 2),
                backgroundColor: AppConstants.primaryPurple,
              ),
            );

            // Navigate to downloads page
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DownloadsScreen()),
            );
          },
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.download, color: Colors.white),
                SizedBox(width: AppConstants.spaceSmall),
                Text(
                  'Download Video',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
