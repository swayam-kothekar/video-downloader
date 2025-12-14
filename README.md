# Video Downloader 🎥

A powerful and feature-rich Flutter Android application for downloading YouTube videos with advanced capabilities including audio-video merging, quality selection, and comprehensive download management.

## ✨ Features

- **🎬 YouTube Video Download**: Download videos from YouTube using just the URL
- **🎯 Quality Selection**: Choose from multiple available video qualities (360p, 720p, 1080p, etc.)
- **🔊 Audio-Video Merging**: Automatic merging of separate audio and video streams for high-quality downloads using FFmpeg
- **📊 Download Progress Tracking**: Real-time progress monitoring with detailed status updates
- **📁 Download Management**: View and manage all downloaded videos in one place
- **🖼️ Video Preview**: See video thumbnails, titles, and file sizes before downloading
- **💾 Smart Storage**: Downloads saved to public Downloads folder with scoped storage access
- **🔐 Modern Permissions**: Uses scoped storage for enhanced privacy and security
- **🎨 Modern UI**: Beautiful and intuitive user interface with smooth animations
- **📱 Responsive Design**: Optimized for various Android screen sizes

## 📲 Installation (For Users)

### Download & Install from Releases

1. **Download the APK**:
   - Go to the [Releases](https://github.com/swayam-kothekar/video-downloader/releases) page
   - Download the latest `.apk` file (e.g., `video-downloader-v1.0.0.apk`)

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
3. **Tap "Fetch Video Info"** to load video details
4. **Review** the video preview with thumbnail, title, and file size
5. **Select desired video quality** from available options
6. **Tap "Download"** to start the download
7. **Monitor progress** in real-time (downloading video, downloading audio, merging)
8. **Access downloads** via the Downloads screen or your device's Downloads folder

---

## 🛠️ Development Setup (For Developers)

### Prerequisites

- **Flutter SDK**: Version 3.10.4 or higher
- **Android Studio** or **VS Code** with Flutter extensions
- **Android Device/Emulator**: Android 6.0 (API level 23) or higher
- **FFmpeg**: Pre-configured for audio-video merging (handled via `flutter_ffmpeg`)

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/video_downloader.git
   cd video_downloader
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Generate app icons** (optional):
   ```bash
   flutter pub run flutter_launcher_icons
   ```

4. **Generate splash screen** (optional):
   ```bash
   flutter pub run flutter_native_splash:create
   ```

5. **Run the app**:
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
│   ├── download_log.dart     # Download tracking model
│   └── video_info.dart       # Video metadata model
├── providers/                # State management
│   └── video_provider.dart   # Video state provider
├── screens/                  # UI screens
│   ├── home_screen.dart      # Main download screen
│   └── downloads_screen.dart # Downloaded videos list
├── services/                 # Business logic
│   ├── youtube_service.dart  # YouTube API interaction
│   ├── download_service.dart # Download management
│   ├── storage_service.dart  # File system operations
│   └── background_download_service.dart # Background downloads
├── theme/                    # App theming
│   └── app_theme.dart        # Custom theme configuration
├── utils/                    # Utilities
│   ├── constants.dart        # App constants
│   └── validators.dart       # Input validation
└── widgets/                  # Reusable widgets
    ├── custom_text_field.dart
    ├── download_progress_card.dart
    └── video_info_card.dart
```

### Key Dependencies

| Package | Purpose |
|---------|---------|
| `youtube_explode_dart` | YouTube video extraction and metadata |
| `dio` | HTTP client for downloading |
| `flutter_downloader` | Background download management |
| `path_provider` | File system path access |
| `permission_handler` | Permission handling |
| `provider` | State management |
| `cached_network_image` | Efficient image loading and caching |
| `google_fonts` | Custom typography |
| `intl` | Date and number formatting |
| `url_launcher` | URL handling |

### How It Works

1. **Video Extraction**: Uses `youtube_explode_dart` to extract video metadata and available streams
2. **Quality Detection**: Identifies all available video qualities and presents them to the user
3. **Stream Analysis**: Determines if audio and video are separate (common for 720p+)
4. **Download Process**:
   - Downloads video stream
   - Downloads audio stream (if separate)
   - Merges streams using FFmpeg into a single MP4 file
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

## 🔧 Configuration

### App Icon

Place your app logo at `assets/images/logo.png` and run:
```bash
flutter pub run flutter_launcher_icons
```

### Splash Screen

Configure splash screen colors in `pubspec.yaml`:
```yaml
flutter_native_splash:
  color: "#1B3A6B"
  image: assets/images/logo.png
```

## 🐛 Troubleshooting

### Permission Issues
- The app will request notification permission on first launch (Android 13+)
- If notifications don't appear, check Settings > Apps > Video Downloader > Notifications

### Download Failures
- Check internet connectivity
- Verify the YouTube URL is valid and accessible
- Some videos may have restrictions preventing downloads
- Ensure sufficient storage space is available

### Merge Failures
- Ensure sufficient storage space
- Check that FFmpeg is properly configured
- Verify both audio and video streams downloaded successfully

### Downloads Not Showing
- Check your device's Downloads folder using a file manager
- Downloaded videos are saved as `[VideoTitle]_[Quality].mp4`

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
