import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constants.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: AppConstants.primary,
        secondary: AppConstants.secondary,
        tertiary: AppConstants.accent,
        surface: AppConstants.surface,
        error: AppConstants.error,
        onPrimary: Colors.white,
        onSurface: AppConstants.textPrimary,
      ),

      // Scaffold
      scaffoldBackgroundColor: AppConstants.background,

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppConstants.border,
        thickness: 1,
        indent: 12,
        endIndent: 12,
      ),

      // Text Theme with Google Fonts Inter
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme.copyWith(
          displayLarge: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppConstants.textPrimary,
            letterSpacing: -0.5,
          ),
          displayMedium: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppConstants.textPrimary,
            letterSpacing: -0.5,
          ),
          displaySmall: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppConstants.textPrimary,
          ),
          headlineMedium: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppConstants.textPrimary,
          ),
          titleLarge: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppConstants.textPrimary,
          ),
          titleMedium: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppConstants.textSecondary,
          ),
          bodyLarge: const TextStyle(
            fontSize: 14, 
            color: AppConstants.textPrimary,
          ),
          bodyMedium: const TextStyle(
            fontSize: 12, 
            color: AppConstants.textSecondary,
          ),
          labelLarge: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppConstants.textPrimary,
          ),
        ),
      ),

      // Card Theme (Minimalist flat cards with 1px border)
      cardTheme: CardThemeData(
        color: AppConstants.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          side: const BorderSide(color: AppConstants.border, width: 1),
        ),
      ),

      // AppBar Theme (Clean, flat, transparent background)
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarColor: Colors.black, // Lock navigation bar to black
          systemNavigationBarIconBrightness: Brightness.light, // Lock navigation bar icons to light
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppConstants.textPrimary,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: AppConstants.textPrimary, size: 20),
      ),

      // Elevated Button Theme (Solid, professional, no complex shadows)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spaceMedium,
            vertical: AppConstants.spaceMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input Decoration Theme (Clean web-like inputs)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppConstants.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: const BorderSide(color: AppConstants.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: const BorderSide(color: AppConstants.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: const BorderSide(
            color: AppConstants.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: const BorderSide(color: AppConstants.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: const BorderSide(color: AppConstants.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(AppConstants.spaceMedium),
        hintStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 14),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(color: AppConstants.textSecondary, size: 20),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppConstants.primary,
        linearTrackColor: AppConstants.border,
      ),

      // ListTile Theme (transparent background to prevent invisible ink splash warning)
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: AppConstants.primary,
        secondary: AppConstants.secondary,
        tertiary: AppConstants.accent,
        surface: Colors.white,
        error: AppConstants.error,
        onPrimary: Colors.white,
        onSurface: Color(0xFF09090B), // Zinc 950
      ),

      // Scaffold
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE4E4E7), // Zinc 200
        thickness: 1,
        indent: 12,
        endIndent: 12,
      ),

      // Text Theme with Google Fonts Inter
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light().textTheme.copyWith(
          displayLarge: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Color(0xFF09090B),
            letterSpacing: -0.5,
          ),
          displayMedium: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Color(0xFF09090B),
            letterSpacing: -0.5,
          ),
          displaySmall: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF09090B),
          ),
          headlineMedium: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF09090B),
          ),
          titleLarge: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF09090B),
          ),
          titleMedium: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF71717A),
          ),
          bodyLarge: const TextStyle(
            fontSize: 14, 
            color: Color(0xFF09090B),
          ),
          bodyMedium: const TextStyle(
            fontSize: 12, 
            color: Color(0xFF71717A),
          ),
          labelLarge: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF09090B),
          ),
        ),
      ),

      // Card Theme (Minimalist flat cards with 1px border)
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          side: const BorderSide(color: Color(0xFFE4E4E7), width: 1),
        ),
      ),

      // AppBar Theme (Clean, flat, transparent background)
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
           statusBarColor: Colors.transparent,
           statusBarIconBrightness: Brightness.dark,
           statusBarBrightness: Brightness.light,
           systemStatusBarContrastEnforced: false, // Prevent Android scrim in light mode
           systemNavigationBarColor: Colors.black, // Lock navigation bar to black
           systemNavigationBarIconBrightness: Brightness.light, // Lock navigation bar icons to light
           systemNavigationBarDividerColor: Colors.transparent,
           systemNavigationBarContrastEnforced: false,
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF09090B),
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF09090B), size: 20),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spaceMedium,
            vertical: AppConstants.spaceMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: const BorderSide(color: Color(0xFFE4E4E7), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: const BorderSide(color: Color(0xFFE4E4E7), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: const BorderSide(
            color: AppConstants.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: const BorderSide(color: AppConstants.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: const BorderSide(color: AppConstants.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(AppConstants.spaceMedium),
        hintStyle: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 14),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(color: Color(0xFF71717A), size: 20),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppConstants.primary,
        linearTrackColor: Color(0xFFE4E4E7),
      ),

      // ListTile Theme (transparent background to prevent invisible ink splash warning)
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
      ),
    );
  }
}
