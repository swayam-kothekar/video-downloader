<div align="center">
  <img src="assets/images/logo_transparent.png" width="96" alt="Video Downloader Logo" />

  # Video Downloader

  **A Flutter Android Application for Downloading YouTube, Instagram, Facebook & Twitter/X Videos**

  <p>
    A high-performance Flutter Android application for downloading videos and reels from YouTube, Instagram, Facebook, and Twitter/X directly to your device. Features native stream extraction, multi-quality options, chunk-based smart resume, background foreground service, Wi-Fi only mode, and Android Scoped Storage compliance with zero broad storage permissions.
  </p>

  <p>
    <a href="https://github.com/swayam-kothekar/video-downloader/releases"><strong>Download Latest APK »</strong></a>
  </p>

  <p>
    <a href="#-overview">Overview</a> &middot;
    <a href="#-features">Features</a> &middot;
    <a href="#-installation-for-users">Installation</a> &middot;
    <a href="#usage">Usage</a> &middot;
    <a href="#️-development-setup-for-developers">Development Setup</a> &middot;
    <a href="#️-technical-details">Technical Details</a>
  </p>

  <p>
    <a href="https://github.com/swayam-kothekar/video-downloader/releases"><img src="https://img.shields.io/badge/DOWNLOAD-LATEST%20APK-7c3aed?style=for-the-badge&logo=android&logoColor=white" alt="Download APK" /></a>
    <img src="https://img.shields.io/badge/PLATFORMS-YOUTUBE%20%7C%20INSTA%20%7C%20FB%20%7C%20X-059669?style=for-the-badge" alt="Platforms" />
    <img src="https://img.shields.io/badge/STORAGE-SCOPED%20STORAGE-6366f1?style=for-the-badge" alt="Scoped Storage" />
    <br />
    <img src="https://img.shields.io/badge/LICENSE-EDUCATIONAL-3b82f6?style=for-the-badge" alt="Educational License" />
  </p>

  <p>
    <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" /></a>
    <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" /></a>
    <a href="https://developer.android.com"><img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android" /></a>
    <img src="https://img.shields.io/badge/YouTube-FF0000?style=for-the-badge&logo=youtube&logoColor=white" alt="YouTube" />
    <img src="https://img.shields.io/badge/Instagram-E4405F?style=for-the-badge&logo=instagram&logoColor=white" alt="Instagram" />
    <img src="https://img.shields.io/badge/Facebook-1877F2?style=for-the-badge&logo=facebook&logoColor=white" alt="Facebook" />
    <img src="https://img.shields.io/badge/X%20%2F%20Twitter-000000?style=for-the-badge&logo=x&logoColor=white" alt="X (Twitter)" />
  </p>
</div>

---

## 📖 Overview

A modern, privacy-focused Flutter Android application for downloading videos from **YouTube**, **Instagram (Reels & Posts)**, **Facebook (Videos & Watch)**, and **Twitter / X** directly to your device. It leverages native stream extraction, multi-tier social scrapers, resilient background download services, and Android Scoped Storage with zero broad file storage permissions required.

## ✨ Features

- **🎬 Multi-Platform Video Extraction**: Extract video metadata and media seamlessly from **YouTube**, **Instagram** (Reels, Posts, IGTV), **Facebook** (Watch, Reels, Videos), and **Twitter / X** (video clips & status links) using multi-tier fallback resolution.
- **⚡ Quality & Format Selection**: Preview media information and choose between multiple available quality streams (HD, SD, 720p, 360p, or audio streams).
- **🛡️ Background Download Protection**: Integrated foreground service (`flutter_foreground_task`) and CPU/Wi-Fi wake locks (`wakelock_plus`) keep downloads active without stalling when the screen is locked or the app is backgrounded.
- **⚡ Parallel & Sequential Downloads**: Process multiple downloads simultaneously with clear multi-stage status tracking, speed metrics, and progress bars.
- **🔄 Smart Resume (Chunk-based Downloading)**: Automatically detects partial or interrupted downloads and resumes the task from the last saved byte offset, avoiding unnecessary data usage.
- **📶 Wi-Fi Only Mode**: Prevent mobile data charges by forcing downloads to pause automatically when switching to cellular networks, resuming when connected back to Wi-Fi.
- **💬 Subtitle & Closed Caption Downloader**: Fetch closed caption tracks (.srt/.vtt) automatically alongside YouTube media files.
- **💾 Scoped Storage Compliance**: Fully targets Android Scoped Storage using `MediaStore` API. Downloads are placed directly into the public `Downloads` directory with **zero broad storage permissions** required.
- **📊 Real-time Metrics & Persistent Logs**: View current download speed (KB/s, MB/s), progress percentages, and status alerts. Keeps a persistent log of recent download operations.
- **🧼 Cache Maintenance**: Monitor the size of temporary files in the app cache and clear them directly within app settings.
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

### Usage

1. **Launch the app** on your Android device
2. **Paste or enter** a video URL from **YouTube**, **Instagram**, **Facebook**, or **Twitter / X** in the input field
3. **Tap "Search Video"** to detect the platform and load video details
4. **Review** the video preview with thumbnail, title, author, and available quality options
5. **Tap "Download"** to start the download
6. **Monitor progress** in real-time on the Downloads dashboard with live speed tracking
7. **Access downloads** directly in your device's public Downloads folder

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
│   └── video_info.dart       # Video metadata model & platform discriminator
├── providers/                # State management
│   ├── theme_provider.dart   # App theme state provider
│   └── video_provider.dart   # Video download state provider with throttled updates
├── screens/                  # UI screens
│   ├── about_screen.dart     # App information & updates check screen
│   ├── downloads_screen.dart # Downloaded videos list screen
│   ├── home_screen.dart      # Main search & download screen with platform chips
│   └── settings_screen.dart  # App configuration settings screen
├── services/                 # Business logic
│   ├── download_service.dart # Download stream worker & direct URL streaming
│   ├── foreground_service_helper.dart # Android foreground task & wake lock management
│   ├── social_media_service.dart # Multi-tier video extractor (Insta, FB, X)
│   ├── storage_service.dart  # Android Scoped Storage integration
│   ├── update_service.dart   # GitHub release updates check service
│   └── youtube_service.dart  # YouTube video metadata extraction
├── theme/                    # App theming
│   └── app_theme.dart        # Theme styles configuration
├── utils/                    # Utilities
│   ├── constants.dart        # App-wide constants
│   └── validators.dart       # Multi-platform URL validators (YT, IG, FB, X)
└── widgets/                  # Reusable widgets
    ├── app_drawer.dart       # Side navigation drawer
    ├── custom_text_field.dart# URL input text field
    ├── download_progress_card.dart # Active download status card
    └── video_info_card.dart  # Video preview card with quality picker
```

### Key Dependencies

| Package | Purpose |
|---------|---------|
| `youtube_explode_dart` | Native YouTube stream extraction and metadata parsing |
| `direct_link` | Multi-platform direct media stream extractor |
| `flutter_foreground_task` | Android foreground service to prevent background process termination |
| `wakelock_plus` | Screen and CPU wake lock keeping active downloads alive |
| `http` | HTTP client for direct media streaming and platform scrapers |
| `dio` | HTTP client for checking GitHub updates |
| `flutter_native_splash` | Configures and generates native splash screens |
| `path_provider` | File system path access |
| `permission_handler` | Permission handling |
| `provider` | Reactive state management |
| `cached_network_image` | Efficient image loading and caching |
| `google_fonts` | Custom typography |
| `intl` | Date and number formatting |
| `url_launcher` | External URL launching |
| `connectivity_plus` | Check Wi-Fi and mobile network connectivity |

### How It Works

1. **Multi-Platform Extraction**:
   - **YouTube**: Handled natively in-app by `youtube_explode_dart` to parse stream manifests and dual audio/video streams.
   - **Instagram, Facebook & Twitter/X**: Processed via `SocialMediaService` utilizing a multi-tier fallback pipeline (`direct_link` package, system `yt-dlp` fallback, and dedicated platform scrapers).
2. **Resilient Streaming Engine**: Handles direct HTTP and chunked streams via `DownloadService` with watchdog timeouts, pause/resume capability, and live byte-per-second speed calculation.
3. **Background Persistence**: Coordinates through `ForegroundServiceHelper` to keep downloads running under Android battery optimization.
4. **Storage**: Saves final video files directly to the public Downloads folder using Android Scoped Storage (`MediaStore`).
5. **Cleanup**: Automatically cleans up temporary streams and buffers upon completion.

### Permissions

The app uses **scoped storage** for modern Android compatibility and enhanced user privacy:

```xml
<!-- Required permissions in AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

**Key Points**:
- ✅ **INTERNET**: Required for fetching video metadata and downloading media streams
- ✅ **FOREGROUND SERVICE / WAKE LOCK**: Allows downloads to complete reliably in the background
- ❌ **No broad storage permissions**: Uses scoped storage targeting only public media collections
- 🔒 **Privacy-first**: No access to personal files or media

---

## 🐛 Troubleshooting

### Download Failures
- Check internet connectivity
- Ensure the video link is from a supported platform (**YouTube**, **Instagram**, **Facebook**, or **Twitter / X**)
- For Instagram and Facebook, verify that the reel or video is publicly accessible
- Ensure sufficient device storage space is available

## 📝 License

This project is for educational purposes. Please respect content creators' rights, platform copyright policies, and terms of service.

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

**Note**: This app is designed for personal use. Always respect content creators' rights and platform Terms of Service.
