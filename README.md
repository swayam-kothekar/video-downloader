# Video Downloader 🎥

A Flutter Android application for downloading YouTube videos directly to your device.

## Features

- **Direct YouTube Extraction**: Extract video metadata and download videos seamlessly with native in-app streaming technology.
- **Parallel & Sequential Downloads**: Process multiple downloads simultaneously with clear multi-stage status tracking, speed metrics, and progress bars.
- **Smart Resume (Chunk-based Downloading)**: Automatically detects partial or interrupted downloads and resumes the task from the last saved byte offset, avoiding unnecessary data usage.
- **Wi-Fi Only Mode**: Prevent mobile data charges by forcing downloads to pause automatically when switching to cellular networks, resuming when connected back to Wi-Fi.
- **Subtitle & Closed Caption Downloader**: Fetch closed caption tracks (.srt/.vtt) automatically alongside media files.
- **Scoped Storage Compliance**: Fully targets Android Scoped Storage using `MediaStore` API. Downloads are placed directly into the public `Downloads` directory with **zero broad storage permissions** required.
- **Real-time Metrics & Persistent Logs**: View current download speed (KB/s, MB/s), progress percentages, and status alerts. Keeps a persistent log of recent download operations.
- **Cache Maintenance**: Monitor the size of temporary files in the app cache and clear them directly within app settings.
- **Modern Theme Engine**: Beautiful UI with smooth micro-animations, radial gradient accents, and dynamic support for Light Mode, Dark Mode, and System Default themes.
- **In-app Update Engine**: Auto-checks GitHub Releases API on startup, prompting the user with a changelog and download link when updates are available.

## Installation (For Users)

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

### Usage

1. **Launch the app** on your Android device
2. **Paste or enter** a YouTube video URL in the text field
3. **Tap "Search Video"** to load video details
4. **Review** the video preview with thumbnail, title, and file size
5. **Tap "Download"** to start the download
6. **Monitor progress** in real-time on the Downloads dashboard
7. **Access downloads** via your device's Downloads folder

---

## 🛠️ Development Setup (For Developers)

### Prerequisites

- **Flutter SDK**: Version 3.10.4 or higher
- **Android Studio** or **VS Code** with Flutter extensions
- **Android Device/Emulator**: Android 6.0 (API level 23) or higher

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
├── main.dart                 # App entry point & async startup initialization
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
    └── video_info_card.dart  # Video preview card
```

### Key Dependencies

| Package | Purpose |
|---------|---------|
| `youtube_explode_dart` | Native YouTube stream extraction and metadata parsing |
| `dio` | HTTP client for checking updates |
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

1. **Video Extraction**: Uses `youtube_explode_dart` directly within the app to extract video metadata and stream URL links.
2. **Sequential Stream Downloading**: Handles dual video/audio stream processing sequentially with live state updates.
3. **Storage**: Saves final video files directly to the public Downloads folder using Android Scoped Storage (`MediaStore`).
4. **Cleanup**: Automatically cleans up temporary streams and buffers upon completion.

### Permissions

The app uses **scoped storage** for modern Android compatibility and enhanced user privacy:

```xml
<!-- Required permissions in AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
```

**Key Points**:
 **INTERNET**: Required for fetching video metadata and downloading streams from YouTube
 **No broad storage permissions**: Uses scoped storage targeting only public media collections
 **Privacy-first**: No access to personal files or media

---

## Troubleshooting

### Download Failures
- Check internet connectivity
- Verify the YouTube URL is valid and accessible
- Ensure sufficient device storage space is available

## License

This project is for educational purposes. Please respect YouTube's Terms of Service and copyright laws.


## 📧 Contact

For questions or support, please open an issue in the repository.

---

**Note**: This app is designed for personal use. Always respect content creators' rights and YouTube's Terms of Service.
