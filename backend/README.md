# YouTube Video Downloader API

A robust, lightweight, and generic backend API built with **FastAPI** and **yt-dlp** to extract video metadata and proxy media downloads. 

This backend is designed to be **client-agnostic**; it can be used with a Flutter mobile app, a web app, a CLI, or any other platform.

---

## Key Features

1. **Detailed Metadata Extraction**: Returns video/playlist title, description, thumbnail, duration, uploader, views, likes, and a list of all available media formats.
2. **Stream Categorization**: Formats are automatically grouped into:
   - `combined`: Streams containing both audio and video (ready-to-watch, typically 360p or 720p).
   - `video_only`: High-definition video-only streams (e.g., 1080p, 1440p, 4K) for clients that support merging video/audio locally.
   - `audio_only`: Audio-only streams (e.g., m4a, webm) for music/podcast players.
3. **Resumable Streaming Proxy**: Features a `/api/download` endpoint that streams media files through the server.
   - **Bypasses IP Restrictions**: YouTube CDN links are often restricted to the IP address that requested them. Proxying downloads bypasses this lock.
   - **Supports Range Requests**: Forwards client `Range` headers to YouTube CDN, enabling pause, resume, and multi-threaded downloading in client download managers.
   - **Low Memory Overhead**: Streams chunks asynchronously (no server buffering or RAM bloat).

---

## Technology Stack

- **Python 3.12+**
- **FastAPI**: Asynchronous web framework.
- **yt-dlp**: Premium YouTube and video platform metadata extractor.
- **HTTPX**: Non-blocking async HTTP client for proxying.
- **Docker**: For simple, uniform deployment.

---

## Quick Start (Local Development)

### 1. Prerequisites
- Python 3.12 or newer
- `ffmpeg` (highly recommended for format parsing/processing)

On Ubuntu/Debian:
```bash
sudo apt update && sudo apt install -y ffmpeg
```

### 2. Setup Virtual Environment & Run
```bash
# Create virtual environment
python3 -m venv .venv

# Activate virtual environment
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run the server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
The API documentation will be available at [http://localhost:8000/docs](http://localhost:8000/docs).

---

## Running with Docker

You can run the backend inside a Docker container. This will automatically set up `ffmpeg` and all required libraries.

```bash
# Build the Docker image
docker build -t yt-downloader-api .

# Run the container
docker run -d -p 8000:8000 --name yt-downloader-api-service yt-downloader-api
```

---

## API Endpoints Reference

### 1. Root Endpoint
* **Path**: `GET /`
* **Purpose**: Health check & documentation link.
* **Response**:
```json
{
  "message": "Welcome to the YouTube Video Downloader API",
  "documentation": "/docs",
  "status": "healthy"
}
```

### 2. Get Video/Playlist Metadata
* **Path**: `GET /api/info`
* **Query Parameters**:
  - `url` (String, required): The URL of the YouTube video or playlist.
* **Example Request**:
  `GET http://localhost:8000/api/info?url=https://www.youtube.com/watch?v=dQw4w9WgXcQ`
* **Response (Video)**:
```json
{
  "is_playlist": false,
  "id": "dQw4w9WgXcQ",
  "title": "Rick Astley - Never Gonna Give You Up (Official Music Video)",
  "description": "The official video for Never Gonna Give You Up...",
  "duration": 212,
  "thumbnail": "https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg",
  "thumbnails": [ ... ],
  "uploader": "Rick Astley",
  "uploader_url": "https://www.youtube.com/@RickAstleyYT",
  "view_count": 1500000000,
  "like_count": 18000000,
  "upload_date": "20091025",
  "formats": [
    {
      "format_id": "18",
      "ext": "mp4",
      "resolution": "640x360",
      "fps": 30,
      "filesize": 15432901,
      "url": "https://rr3---sn-u2xg87gd...",
      "type": "combined",
      "video_codec": "h264",
      "audio_codec": "aac",
      "quality_label": "360p",
      "container": "mp4",
      "download_proxy_url": "http://localhost:8000/api/download?url=https%3A%2F%2Frr3---sn-u2xg87gd...&filename=Rick_Astley_-_Never_Gonna_Give_You_Up_360p_18.mp4"
    }
  ]
}
```

### 3. Proxy Video Download
* **Path**: `GET /api/download`
* **Query Parameters**:
  - `url` (String, required): The URL-encoded direct YouTube CDN format URL (extracted from `url` in the `/api/info` format details).
  - `filename` (String, optional): The name of the file when downloaded (defaults to `video.mp4`).
* **Headers Supported**:
  - `Range`: Forwarded to YouTube. If present, server responds with `206 Partial Content` and streams the requested range.
* **Example Request**:
  `GET http://localhost:8000/api/download?url=<URL_ENCODED_STREAM_URL>&filename=rickroll.mp4`

---

## Client Integration Guide (Flutter/Dart)

To consume this API in a Flutter application, you can use the `dio` package, which has built-in support for saving files to disk, tracking download progress, and cancelling requests.

### 1. Fetching Video Metadata
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>?> fetchVideoInfo(String youtubeUrl) async {
  final apiBaseUrl = 'http://YOUR_SERVER_IP:8000';
  final response = await http.get(
    Uri.parse('$apiBaseUrl/api/info?url=${Uri.encodeComponent(youtubeUrl)}'),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    print('Failed to get video info: ${response.statusCode}');
    return null;
  }
}
```

### 2. Downloading Video with Progress Bar
```dart
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

Future<void> downloadVideo(String proxyUrl, String filename, Function(int, int) onProgress) async {
  final dio = Dio();
  
  // Get storage directory (e.g. Downloads or Documents directory)
  final dir = await getApplicationDocumentsDirectory();
  final savePath = '${dir.path}/$filename';
  
  try {
    await dio.download(
      proxyUrl,
      savePath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          onProgress(received, total);
        }
      },
    );
    print('Video downloaded to: $savePath');
  } catch (e) {
    print('Download error: $e');
  }
}
```
