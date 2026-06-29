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
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: MarqueeText(
                    text: status,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndStartScrolling());
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndStartScrolling());
    }
  }

  void _checkAndStartScrolling() async {
    if (!mounted || _isScrolling) return;
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    _isScrolling = true;

    while (mounted && _scrollController.hasClients) {
      final currentMax = _scrollController.position.maxScrollExtent;
      if (currentMax <= 0) break;

      final durationMs = (currentMax * 40).toInt().clamp(1500, 10000);

      // Start scrolling immediately
      await _scrollController.animateTo(
        currentMax,
        duration: Duration(milliseconds: durationMs),
        curve: Curves.easeInOut,
      );

      if (!mounted || !_scrollController.hasClients) break;
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted || !_scrollController.hasClients) break;

      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOut,
      );

      if (!mounted || !_scrollController.hasClients) break;
      await Future.delayed(const Duration(milliseconds: 600));
    }

    _isScrolling = false;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
      ),
    );
  }
}
