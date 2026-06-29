# Video Downloader 🎥

A Flutter Android application for downloading YouTube videos.

## ✨ Features

- **🎬 YouTube Video & Audio Extraction**: Parse YouTube URLs to extract metadata. Choose from a wide range of video resolutions (144p, 240p, 360p, 480p, 720p, 1080p, 2K, 4K) or download high-bitrate M4A audio only.
- **⚡ Parallel/Simultaneous Downloads**: Download multiple videos and audio tracks at the same time, complete with individual speed metrics, progress bars, and independent pause/cancel controls.
- **🛠️ Smart Audio-Video Merging (FFmpeg)**: High-resolution formats on YouTube separate audio and video streams. The app automatically downloads both, then merges them on the fly using native FFmpeg (`ffmpeg_kit_flutter_new`) with fallback codec transcoders.
- **🔄 Smart Resume (Chunk-based Downloading)**: Automatically detects partial or interrupted downloads and resumes the task from the last saved byte offset, avoiding unnecessary data usage.
- **📶 Wi-Fi Only Mode**: Prevent mobile data charges by forcing downloads to pause automatically when switching to cellular networks, resuming when connected back to Wi-Fi.
- **💬 Subtitle & Closed Caption Downloader**: Fetch closed caption tracks (.srt/.vtt) automatically in the background alongside the media files.
- **💾 Scoped Storage Compliance**: Fully targets Android Scoped Storage using `MediaStore` API. Downloads are securely placed directly into the public `Downloads` directory, requiring **zero broad storage permissions** (such as read/write external storage).
- **📊 Real-time Metrics & Persistent Logs**: View current download speed (KB/s, MB/s), progress percentages, and status alerts. Keeps a persistent log of the last 50 download operations.
- **🧼 Cache Maintenance**: Monitor the size of temporary files in the app cache and clear them directly within the app settings.
- **🎨 Modern Theme Engine**: Beautiful UI with smooth micro-animations, radial gradient accents, and dynamic support for Light Mode, Dark Mode, and System Default themes.
- **🚀 In-app Update Engine**: Auto-checks GitHub Releases API on startup, prompting the user with a changelog and download link when updates are available.

## 📲 Installation (For Users)

### Download & Install from Releases

1. **Download the APK**:
   - Go to the [Releases](https://github.com/swayam-kothekar/video-downloader/releases) page
   - Download the latest `.apk` file

2. **Enable Unknown Sources** (if needed):
   - Go to **Settings** > **Security** or **Privacy**
   - Enable **Install from Unknown Sources** or **Allow from this source** for your browser/file manager

3. **Install the APK**:
   - Open the downloaded APK file
   - Tap **Install**
   - Wait for the installation to complete
   - Tap **Open** to launch the app

4. **Grant Permissions**:
   - The app will request notification permission for download progress tracking
   - Grant the permission to enable background downloads with progress notifications

### Usage

1. **Launch the app** on your Android device
2. **Paste or enter** a YouTube video URL in the text field
3. **Tap "Search Video"** to load video details
4. **Review** the video preview with thumbnail, title, and file size
5. **Select video or only audio** to be downloaded
6. **Tap "Download"** to start the download
7. **Monitor progress** in real-time
8. **Access downloads** via your device's Downloads folder

---

## 🛠️ Development Setup (For Developers)

### Prerequisites

- **Flutter SDK**: Version 3.10.4 or higher
- **Android Studio** or **VS Code** with Flutter extensions
- **Android Device/Emulator**: Android 6.0 (API level 23) or higher
- **FFmpeg**: Pre-configured for audio-video merging (handled via `ffmpeg_kit_flutter_new`)

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/swayam-kothekar/video-downloader.git
   cd video-downloader
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the app**:
   ```bash
   flutter run
   ```

### Build Release APK

To create a release build:

```bash
flutter build apk --release
```

The APK will be generated at `build/app/outputs/flutter-apk/app-release.apk`.

## 🛠️ Technical Details

### Architecture

The app follows a clean, modular architecture:

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── active_download.dart  # Active download tracking model
│   ├── download_log.dart     # Completed downloads history model
│   └── video_info.dart       # Video metadata model
├── providers/                # State management
│   ├── theme_provider.dart   # App theme state provider
│   └── video_provider.dart   # Video download state provider
├── screens/                  # UI screens
│   ├── about_screen.dart     # App information & updates check screen
│   ├── downloads_screen.dart # Downloaded videos list screen
│   ├── home_screen.dart      # Main search & download screen
│   └── settings_screen.dart  # App configuration settings screen
├── services/                 # Business logic
│   ├── download_service.dart # Download stream worker
│   ├── storage_service.dart  # Android Scoped Storage integration
│   ├── update_service.dart   # GitHub release updates check service
│   └── youtube_service.dart  # YouTube video metadata extraction
├── theme/                    # App theming
│   └── app_theme.dart        # Theme styles configuration
├── utils/                    # Utilities
│   ├── constants.dart        # App-wide constants
│   └── validators.dart       # Input validators
└── widgets/                  # Reusable widgets
    ├── app_drawer.dart       # Side navigation drawer
    ├── custom_text_field.dart# URL input text field
    ├── download_progress_card.dart # Active download status card
    └── video_info_card.dart  # Video preview and options card
```

### Key Dependencies

| Package | Purpose |
|---------|---------|
| `youtube_explode_dart` | YouTube video extraction and metadata |
| `dio` | HTTP client for checking updates |
| `ffmpeg_kit_flutter_new` | Merges audio and video streams using FFmpeg |
| `flutter_native_splash` | Configures and generates native splash screens |
| `path_provider` | File system path access |
| `permission_handler` | Permission handling |
| `provider` | State management |
| `cached_network_image` | Efficient image loading and caching |
| `google_fonts` | Custom typography |
| `intl` | Date and number formatting |
| `url_launcher` | URL handling |
| `connectivity_plus` | Check network connectivity status |

### How It Works

1. **Video Extraction**: Uses `youtube_explode_dart` to extract video metadata and available streams
2. **Quality Detection**: Identifies all available video qualities and presents them to the user
3. **Stream Analysis**: Determines if audio and video are separate
4. **Download Process**: Downloads video stream
5. **Storage**: Saves final video to public Downloads folder using scoped storage
6. **Cleanup**: Removes temporary files after successful merge

### Permissions

The app uses **scoped storage** for modern Android compatibility and enhanced user privacy:

```xml
<!-- Required permissions in AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

**Key Points**:
- ✅ **INTERNET**: Required for downloading videos from YouTube
- ✅ **FOREGROUND_SERVICE**: Enables background downloads with persistent notifications
- ✅ **POST_NOTIFICATIONS**: Shows download progress notifications (Android 13+)
- ❌ **No broad storage permissions**: Uses scoped storage, targeting only the Downloads folder
- 🔒 **Privacy-first**: No access to user's personal files or media


## 🐛 Troubleshooting

### Permission Issues
- The app will request notification permission on first launch (Android 13+)
- If notifications don't appear, check Settings > Apps > Video Downloader > Notifications

### Download Failures
- Check internet connectivity
- Verify the YouTube URL is valid and accessible
- Some videos may have restrictions preventing downloads
- Ensure sufficient storage space is available

## 📝 License

This project is for educational purposes. Please respect YouTube's Terms of Service and copyright laws.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📧 Contact

For questions or support, please open an issue in the repository.

---

**Note**: This app is designed for personal use. Always respect content creators' rights and YouTube's Terms of Service.
