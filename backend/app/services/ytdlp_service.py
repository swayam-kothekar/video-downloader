import yt_dlp
import logging
from typing import Any, Dict, List
from app.config import settings

logger = logging.getLogger("ytdlp_service")

class YTDLPService:
    @staticmethod
    def get_video_info(url: str) -> Dict[str, Any]:
        """
        Extract metadata and format information from a YouTube URL using yt-dlp.
        """
        ydl_opts = {
            'quiet': True,
            'no_warnings': True,
            'format': 'best',
            # Avoid downloading the video, only extract info
            'extract_flat': False,
        }
        
        if settings.HTTP_PROXY:
            ydl_opts['proxy'] = settings.HTTP_PROXY
            
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            try:
                # We extract info without downloading
                info = ydl.extract_info(url, download=False)
                if not info:
                    raise Exception("Failed to extract video information.")
                
                # Check if it is a playlist and extract first entry or handle it
                if '_type' in info and info['_type'] == 'playlist':
                    # If it's a playlist, we return basic playlist info or the first video
                    entries = list(info.get('entries', []))
                    if not entries:
                        raise Exception("The playlist is empty.")
                    # Return playlist details and let client know it's a playlist
                    return YTDLPService._parse_playlist(info)
                
                return YTDLPService._parse_video(info)
            except Exception as e:
                logger.error(f"Error extracting video info: {str(e)}")
                raise e

    @staticmethod
    def _parse_playlist(info: Dict[str, Any]) -> Dict[str, Any]:
        """
        Parse playlist metadata.
        """
        parsed_entries = []
        for entry in info.get('entries', []):
            if not entry:
                continue
            parsed_entries.append({
                "id": entry.get("id"),
                "title": entry.get("title"),
                "url": f"https://www.youtube.com/watch?v={entry.get('id')}",
                "duration": entry.get("duration"),
                "uploader": entry.get("uploader"),
                "view_count": entry.get("view_count"),
            })
            
        return {
            "is_playlist": True,
            "id": info.get("id"),
            "title": info.get("title"),
            "description": info.get("description"),
            "uploader": info.get("uploader"),
            "video_count": len(parsed_entries),
            "videos": parsed_entries
        }

    @staticmethod
    def _parse_video(info: Dict[str, Any]) -> Dict[str, Any]:
        """
        Parse video metadata and extract clean formats.
        """
        video_id = info.get("id")
        title = info.get("title")
        description = info.get("description")
        duration = info.get("duration")
        uploader = info.get("uploader")
        uploader_url = info.get("uploader_url")
        view_count = info.get("view_count")
        like_count = info.get("like_count")
        upload_date = info.get("upload_date")
        
        # Get highest quality thumbnail
        thumbnails = info.get("thumbnails", [])
        thumbnail = info.get("thumbnail")
        if thumbnails:
            # Sort thumbnails by area (width * height) descending
            valid_thumbnails = [t for t in thumbnails if t.get("width") and t.get("height")]
            if valid_thumbnails:
                best_thumbnail = max(valid_thumbnails, key=lambda t: t["width"] * t["height"])
                thumbnail = best_thumbnail.get("url", thumbnail)
        
        raw_formats = info.get("formats", [])
        formats = []
        
        for fmt in raw_formats:
            # We need format URL to download, and we skip manifest files like m3u8 / mpd for general downloads
            fmt_url = fmt.get("url")
            if not fmt_url or ".m3u8" in fmt_url or ".mpd" in fmt_url:
                continue
                
            vcodec = fmt.get("vcodec", "none")
            acodec = fmt.get("acodec", "none")
            
            # Determine stream type
            has_video = vcodec != "none" and vcodec is not None
            has_audio = acodec != "none" and acodec is not None
            
            if has_video and has_audio:
                stream_type = "combined"
            elif has_video:
                stream_type = "video_only"
            elif has_audio:
                stream_type = "audio_only"
            else:
                continue # Skip unknown formats
                
            # Get size in bytes
            filesize = fmt.get("filesize")
            if filesize is None:
                filesize = fmt.get("filesize_approx")
                
            # Quality label / resolution info
            resolution = fmt.get("resolution")
            quality_label = fmt.get("format_note")
            
            if stream_type == "audio_only":
                abr = fmt.get("abr")
                quality_label = f"{int(abr)}kbps" if abr else fmt.get("format_note") or "audio"
                resolution = "audio"
            else:
                if not quality_label:
                    height = fmt.get("height")
                    quality_label = f"{height}p" if height else "video"
            
            formats.append({
                "format_id": fmt.get("format_id"),
                "ext": fmt.get("ext"),
                "resolution": resolution,
                "fps": fmt.get("fps"),
                "filesize": filesize,
                "url": fmt_url,
                "type": stream_type,
                "video_codec": vcodec if has_video else None,
                "audio_codec": acodec if has_audio else None,
                "quality_label": quality_label,
                "container": fmt.get("container") or fmt.get("ext"),
            })
            
        return {
            "is_playlist": False,
            "id": video_id,
            "title": title,
            "description": description,
            "duration": duration,
            "thumbnail": thumbnail,
            "thumbnails": [t.get("url") for t in thumbnails if t.get("url")],
            "uploader": uploader,
            "uploader_url": uploader_url,
            "view_count": view_count,
            "like_count": like_count,
            "upload_date": upload_date,
            "formats": formats
        }
