import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'providers/video_provider.dart';
import 'providers/theme_provider.dart';
import 'services/youtube_service.dart';
import 'services/download_service.dart';
import 'services/storage_service.dart';


Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  // Enable edge-to-edge: content draws behind status bar & navigation bar
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);


  // Pre-load settings before the first frame so ThemeProvider is ready
  // and avoids a first-run freeze from async file I/O during build()
  final themeProvider = ThemeProvider();
  await themeProvider.waitForLoad();

  runApp(MyApp(themeProvider: themeProvider));
}

class MyApp extends StatelessWidget {
  final ThemeProvider themeProvider;

  const MyApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider(
          create: (_) => VideoProvider(
            YouTubeService(),
            DownloadService(),
            StorageService(),
          ),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final systemBrightness = MediaQuery.platformBrightnessOf(context);
          final isDark = themeProvider.themeMode == ThemeMode.system
              ? systemBrightness == Brightness.dark
              : themeProvider.themeMode == ThemeMode.dark;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
              systemStatusBarContrastEnforced: false,
              systemNavigationBarColor: Colors.black,
              systemNavigationBarIconBrightness: Brightness.light,
              systemNavigationBarDividerColor: Colors.transparent,
              systemNavigationBarContrastEnforced: false,
            ),
            child: MaterialApp(
              title: 'Video Downloader',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeProvider.themeMode,
              themeAnimationDuration: Duration.zero,
              debugShowCheckedModeBanner: false,
              home: const HomeScreen(),
            ),
          );
        },
      ),
    );
  }
}

