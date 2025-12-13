import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'providers/video_provider.dart';
import 'services/youtube_service.dart';
import 'services/background_download_service.dart';
import 'services/storage_service.dart';

@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  // This callback will be called in the background
  // We'll implement proper handling later
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize flutter_downloader
  await FlutterDownloader.initialize(debug: true, ignoreSsl: false);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => VideoProvider(
            YouTubeService(),
            BackgroundDownloadService(),
            StorageService(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'YouTube Downloader',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: const HomeScreen(),
      ),
    );
  }
}
