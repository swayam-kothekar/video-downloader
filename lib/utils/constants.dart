import 'package:flutter/material.dart';

class AppConstants {
  // App Information
  static const String appName = 'Video Downloader';
  static const String appVersion = '2.0.0';

  // Neutral Theme Colors (Zinc design system)
  static const Color background = Color(0xFF09090B); // Zinc 950 (Scaffold background)
  static const Color surface = Color(0xFF18181B);    // Zinc 900 (Inputs, cards)
  static const Color card = Color(0xFF1E1E24);       // Premium zinc-850 for cards
  static const Color border = Color(0xFF27272A);     // Zinc 800 (Clean divider/border)
  static const Color borderLight = Color(0xFF3F3F46); // Zinc 700 (Highlight border)

  // Brand Colors
  static const Color primary = Color(0xFF6366F1);    // Indigo 500
  static const Color secondary = Color(0xFF14B8A6);  // Teal 500
  static const Color accent = Color(0xFF0EA5E9);     // Sky 500
  
  // Status Colors (Strictly no red/orange!)
  static const Color success = Color(0xFF10B981);    // Emerald 500
  static const Color warning = Color(0xFFEAB308);    // Amber 500
  static const Color error = Color(0xFFD946EF);      // Fuchsia 500 (For error states instead of red)
  
  // Text Colors
  static const Color textPrimary = Color(0xFFFAFAFA);   // Zinc 50
  static const Color textSecondary = Color(0xFFA1A1AA); // Zinc 400
  static const Color textMuted = Color(0xFF71717A);     // Zinc 500

  // Gradients (Super subtle, professional, no red/orange)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [background, Color(0xFF121216)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Border Radius (Modern, slightly tighter corners)
  static const double radiusSmall = 6.0;
  static const double radiusMedium = 10.0;
  static const double radiusLarge = 14.0;
  static const double radiusXLarge = 20.0;

  // Spacing
  static const double spaceXSmall = 4.0;
  static const double spaceSmall = 8.0;
  static const double spaceMedium = 16.0;
  static const double spaceLarge = 24.0;
  static const double spaceXLarge = 32.0;

  // Animation Durations (milliseconds)
  static const int animationFast = 150;
  static const int animationNormal = 250;
  static const int animationSlow = 400;

  // Video Quality Options
  static const List<String> videoQualities = [
    'Highest Available',
    '1080p',
    '720p',
    '480p',
    '360p',
    'Audio Only',
  ];

  // Sentinel value for "pick highest available quality"
  static const String qualityHighestAvailable = 'Highest Available';

  // Download directory name
  static const String downloadFolderName = 'YouTubeDownloads';
}
