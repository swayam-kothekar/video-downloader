import urllib.parse
from fastapi import FastAPI, HTTPException, Query, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
import httpx
import logging
import asyncio
import os
import shutil

from app.config import settings
from app.services.ytdlp_service import YTDLPService

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger("main")

app = FastAPI(
    title=settings.APP_NAME,
    description="A generic and robust YouTube video metadata extractor and download proxy API.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {
        "message": "Welcome to the YouTube Video Downloader API",
        "documentation": "/docs",
        "status": "healthy"
    }

@app.get("/api/info")
def get_video_info(
    url: str = Query(..., description="The YouTube video or playlist URL"),
    request: Request = None
):
    """
    Extracts metadata and direct download links for a YouTube video/playlist.
    Also injects proxy download URLs for direct downloading via this backend.
    """
    if not url:
        raise HTTPException(status_code=400, detail="URL parameter is required.")
        
    try:
        info = YTDLPService.get_video_info(url)
        
        # Determine the base URL for generating proxy download links
        if settings.BASE_URL:
            base_url = settings.BASE_URL.rstrip('/')
        else:
            # Dynamically determine base URL from request headers
            base_url = f"{request.url.scheme}://{request.url.netloc}"
            
        # If it's a playlist, return playlist metadata directly
        if info.get("is_playlist"):
            return info
            
        # Inject proxy download links for the formats
        title = info.get("title", "video")
        # Sanitize filename (remove characters that are invalid in filenames)
        safe_title = "".join([c if c.isalnum() or c in "._-" else "_" for c in title])
        
        for fmt in info.get("formats", []):
            ext = fmt.get("ext", "mp4")
            format_id = fmt.get("format_id", "")
            quality = fmt.get("quality_label", "")
            
            # Construct a descriptive filename
            filename = f"{safe_title}_{quality}_{format_id}.{ext}"
            encoded_filename = urllib.parse.quote(filename)
            encoded_url = urllib.parse.quote(fmt.get("url", ""))
            
            # Add proxy URL to format
            proxy_url = f"{base_url}/api/download?url={encoded_url}&filename={encoded_filename}"
            fmt["download_proxy_url"] = proxy_url
            
        return info
    except Exception as e:
        logger.error(f"Failed to fetch metadata for URL: {url}, error: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/download")
async def proxy_download(
    url: str = Query(..., description="The direct video stream URL or YouTube watch URL"),
    filename: str = Query("video.mp4", description="The filename for the downloaded file"),
    format_id: str = Query(None, description="The format ID if url is a YouTube watch URL"),
    quality: str = Query(None, description="The desired quality (e.g., 720p, 360p, best, audio)"),
    request: Request = None
):
    """
    Proxies the download from YouTube's CDN to the client.
    Supports HTTP Range requests for resuming and multi-part downloading.
    """
    if not url:
        raise HTTPException(status_code=400, detail="Direct stream URL is required.")
        
    # Re-assemble the video URL (it might contain query parameters)
    # The client might send double-encoded URLs, so we decode it once
    decoded_url = urllib.parse.unquote(url)
    
    # Check if this is a YouTube watch/video URL instead of a direct CDN stream URL.
    is_youtube_page = ("youtube.com" in decoded_url or "youtu.be" in decoded_url) and \
                       ("googlevideo.com" not in decoded_url and "videoplayback" not in decoded_url)
                       
    if is_youtube_page:
        # If no format_id and no quality parameter is specified, return a 300 Multiple Choices list
        if not format_id and not quality:
            logger.info(f"YouTube page URL provided without format_id or quality. Listing options.")
            try:
                info = YTDLPService.get_video_info(decoded_url)
                if info.get("is_playlist"):
                    raise HTTPException(status_code=400, detail="Cannot download a playlist directly. Please provide a single video URL.")
                
                # Determine base URL for generating choices
                if settings.BASE_URL:
                    base_url = settings.BASE_URL.rstrip('/')
                else:
                    base_url = f"{request.url.scheme}://{request.url.netloc}" if request else "http://localhost:8000"
                
                formats_list = []
                for fmt in info.get("formats", []):
                    fid = fmt.get("format_id")
                    q = fmt.get("quality_label")
                    ext = fmt.get("ext")
                    ftype = fmt.get("type")
                    filesize = fmt.get("filesize")
                    
                    # Set description based on format type to make it clear what has audio
                    if ftype == "combined":
                        desc = "Video + Audio (Recommended)"
                    elif ftype == "video_only":
                        if shutil.which("ffmpeg"):
                            desc = "Video Only (No Audio - Auto-merged with Audio)"
                        else:
                            desc = "Video Only (No Audio - Silent, FFmpeg not installed)"
                    elif ftype == "audio_only":
                        desc = "Audio Only (No Video)"
                    else:
                        desc = ftype
                    
                    # Encode params
                    encoded_video_url = urllib.parse.quote(decoded_url)
                    encoded_filename = urllib.parse.quote(f"{info.get('title', 'video')}_{q}_{fid}.{ext}")
                    
                    download_url = f"{base_url}/api/download?url={encoded_video_url}&format_id={fid}&filename={encoded_filename}"
                    
                    formats_list.append({
                        "format_id": fid,
                        "quality": q,
                        "ext": ext,
                        "type": ftype,
                        "description": desc,
                        "filesize": filesize,
                        "download_url": download_url
                    })
                    
                return JSONResponse(
                    status_code=300,
                    content={
                        "detail": "Multiple formats available. Please choose a format by adding 'format_id' or 'quality' to your request.",
                        "title": info.get("title"),
                        "thumbnail": info.get("thumbnail"),
                        "duration": info.get("duration"),
                        "formats": formats_list
                    }
                )
            except HTTPException:
                raise
            except Exception as e:
                logger.error(f"Error listing YouTube formats: {str(e)}")
                raise HTTPException(status_code=400, detail=f"Failed to resolve YouTube URL formats: {str(e)}")

        logger.info(f"Detected YouTube video page URL instead of direct stream URL. Resolving stream URL for: {decoded_url}")
        try:
            info = YTDLPService.get_video_info(decoded_url)
            if info.get("is_playlist"):
                raise HTTPException(status_code=400, detail="Cannot download a playlist directly. Please provide a single video URL.")
            
            # Find the requested format or the best combined format
            stream_url = None
            video_stream_url = None
            audio_stream_url = None
            formats = info.get("formats", [])
            
            if format_id:
                for fmt in formats:
                    if fmt.get("format_id") == format_id:
                        stream_url = fmt.get("url")
                        if filename == "video.mp4" and fmt.get("ext"):
                            filename = f"video.{fmt.get('ext')}"
                        break
            
            if not stream_url and not video_stream_url:
                target_quality = (quality or "best").lower()
                
                if target_quality == "audio":
                    # Audio only requested
                    audio_formats = [f for f in formats if f.get("type") == "audio_only"]
                    if audio_formats:
                        audio_formats.sort(key=lambda f: f.get("filesize") or 0, reverse=True)
                        stream_url = audio_formats[0].get("url")
                        if filename == "video.mp4" and audio_formats[0].get("ext"):
                            filename = f"video.{audio_formats[0].get('ext')}"
                else:
                    # We want video!
                    video_fmt = None
                    
                    if target_quality in ("best", "highest"):
                        # Get best video or combined
                        video_formats = [f for f in formats if f.get("type") in ("video_only", "combined")]
                        if video_formats:
                            def parse_height(f):
                                res = f.get("resolution", "")
                                if "x" in res:
                                    try:
                                        return int(res.split("x")[-1])
                                    except ValueError:
                                        return 0
                                return 0
                            video_formats.sort(key=parse_height, reverse=True)
                            video_fmt = video_formats[0]
                    elif target_quality in ("worst", "lowest"):
                        video_formats = [f for f in formats if f.get("type") in ("video_only", "combined")]
                        if video_formats:
                            def parse_height(f):
                                res = f.get("resolution", "")
                                if "x" in res:
                                    try:
                                        return int(res.split("x")[-1])
                                    except ValueError:
                                        return 99999
                                return 99999
                            video_formats.sort(key=parse_height)
                            video_fmt = video_formats[0]
                    else:
                        # Match quality string (like "720p", "1080p")
                        video_formats = [f for f in formats if f.get("type") in ("video_only", "combined")]
                        for fmt in video_formats:
                            q_label = str(fmt.get("quality_label", "")).lower()
                            if target_quality in q_label or q_label in target_quality:
                                video_fmt = fmt
                                break
                                
                        # Fallback if specific quality not found
                        if not video_fmt:
                            video_formats = [f for f in formats if f.get("type") in ("video_only", "combined")]
                            if video_formats:
                                # Sort by resolution descending
                                def parse_height(f):
                                    res = f.get("resolution", "")
                                    if "x" in res:
                                        try:
                                            return int(res.split("x")[-1])
                                        except ValueError:
                                            return 0
                                    return 0
                                video_formats.sort(key=parse_height, reverse=True)
                                video_fmt = video_formats[0]
                                
                    if video_fmt:
                        if video_fmt.get("type") == "combined":
                            stream_url = video_fmt.get("url")
                            if filename == "video.mp4" and video_fmt.get("ext"):
                                filename = f"video.{video_fmt.get('ext')}"
                        else:
                            # video_only format selected! Check if FFmpeg is available
                            if shutil.which("ffmpeg"):
                                video_stream_url = video_fmt.get("url")
                                
                                # Find best audio format
                                audio_formats = [f for f in formats if f.get("type") == "audio_only"]
                                if audio_formats:
                                    audio_formats.sort(key=lambda f: f.get("filesize") or 0, reverse=True)
                                    audio_stream_url = audio_formats[0].get("url")
                                    
                                if not audio_stream_url:
                                    stream_url = video_stream_url
                                    if filename == "video.mp4" and video_fmt.get("ext"):
                                        filename = f"video.{video_fmt.get('ext')}"
                                else:
                                    filename = f"video.mp4"
                            else:
                                logger.warning("FFmpeg is not installed/found. Falling back to the best combined format (with audio).")
                                # Fallback to best combined format since ffmpeg is missing
                                combined_formats = [f for f in formats if f.get("type") == "combined"]
                                if combined_formats:
                                    def sort_key(f):
                                        res = f.get("resolution", "")
                                        height = 0
                                        if "x" in res:
                                            try:
                                                height = int(res.split("x")[1])
                                            except ValueError:
                                                pass
                                        elif isinstance(res, str) and res.isdigit():
                                            height = int(res)
                                        filesize = f.get("filesize") or 0
                                        return (height, filesize)
                                    
                                    combined_formats.sort(key=sort_key, reverse=True)
                                    stream_url = combined_formats[0].get("url")
                                    if filename == "video.mp4" and combined_formats[0].get("ext"):
                                        filename = f"video.{combined_formats[0].get('ext')}"
            
            # Fallback path if we didn't find any format
            if not stream_url and not video_stream_url:
                combined_formats = [f for f in formats if f.get("type") == "combined"]
                if combined_formats:
                    def sort_key(f):
                        res = f.get("resolution", "")
                        height = 0
                        if "x" in res:
                            try:
                                height = int(res.split("x")[1])
                            except ValueError:
                                pass
                        elif isinstance(res, str) and res.isdigit():
                            height = int(res)
                        filesize = f.get("filesize") or 0
                        return (height, filesize)
                    
                    combined_formats.sort(key=sort_key, reverse=True)
                    stream_url = combined_formats[0].get("url")
                    if filename == "video.mp4" and combined_formats[0].get("ext"):
                        filename = f"video.{combined_formats[0].get('ext')}"
                        
            if not stream_url and not video_stream_url and formats:
                stream_url = formats[0].get("url")
                if filename == "video.mp4" and formats[0].get("ext"):
                    filename = f"video.{formats[0].get('ext')}"
                    
            if not stream_url and not video_stream_url:
                raise HTTPException(status_code=400, detail="Could not extract any stream URLs from the YouTube video page.")
                
            if stream_url:
                decoded_url = stream_url
                
            # Update the filename to the actual video title
            if filename.startswith("video."):
                title = info.get("title", "video")
                safe_title = "".join([c if c.isalnum() or c in "._-" else "_" for c in title])
                ext = filename.split(".")[-1]
                filename = f"{safe_title}.{ext}"
                
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Error resolving YouTube watch URL: {str(e)}")
            raise HTTPException(status_code=400, detail=f"Failed to resolve YouTube URL: {str(e)}")
    
    # Check if we need to merge separate video and audio streams
    if 'video_stream_url' in locals() and video_stream_url and audio_stream_url:
        if not shutil.which("ffmpeg"):
            logger.error("FFmpeg not found in PATH when trying to merge streams.")
            raise HTTPException(
                status_code=500,
                detail="FFmpeg is not installed on the server. Merged high-quality downloads are not supported."
            )
            
        logger.info(f"Merging video and audio streams on-the-fly using FFmpeg for: {filename}")
        async def stream_merged_chunks():
            cmd = [
                "ffmpeg",
                "-y",
                "-loglevel", "error",
                "-user_agent", (
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/120.0.0.0 Safari/537.36"
                ),
                "-i", video_stream_url,
                "-user_agent", (
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/120.0.0.0 Safari/537.36"
                ),
                "-i", audio_stream_url,
                "-c:v", "copy",
                "-c:a", "aac",
                "-f", "mp4",
                "-movflags", "frag_keyframe+empty_moov+default_base_moof",
                "pipe:1"
            ]
            
            # Setup proxy environment if configured
            subprocess_env = os.environ.copy()
            if settings.HTTP_PROXY:
                subprocess_env["http_proxy"] = settings.HTTP_PROXY
                subprocess_env["https_proxy"] = settings.HTTP_PROXY
                
            try:
                process = await asyncio.create_subprocess_exec(
                    *cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.DEVNULL,
                    env=subprocess_env
                )
            except FileNotFoundError:
                logger.error("FFmpeg not found. Cannot merge video and audio.")
                raise HTTPException(
                    status_code=500, 
                    detail="FFmpeg is not installed on the server. Merged high-quality downloads are not supported."
                )
            
            try:
                while True:
                    chunk = await process.stdout.read(524288) # 512KB chunks
                    if not chunk:
                        break
                    yield chunk
            except Exception as stream_err:
                logger.error(f"Error streaming merged video to client: {str(stream_err)}")
            finally:
                if process.returncode is None:
                    try:
                        process.terminate()
                        await process.wait()
                    except Exception:
                        pass
                        
        response_headers = {
            "Content-Disposition": f'attachment; filename="{filename}"',
            "Cache-Control": "no-cache",
            "Content-Type": "video/mp4"
        }
        
        return StreamingResponse(
            stream_merged_chunks(),
            status_code=200,
            headers=response_headers
        )

    # Setup request headers to forward to YouTube CDN
    headers = {
        # Emulate a standard web browser to bypass YouTube bot protections
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/120.0.0.0 Safari/537.36"
        )
    }
    
    # Forward the Range header if sent by the client (allows resuming downloads)
    range_header = request.headers.get("range")
    if range_header:
        headers["Range"] = range_header
        logger.info(f"Forwarding Range header: {range_header}")
        
    # We will use httpx to fetch the video and stream it to the client
    client_kwargs = {
        "timeout": 60.0,
        "follow_redirects": True
    }
    if settings.HTTP_PROXY:
        client_kwargs["proxy"] = settings.HTTP_PROXY
    client = httpx.AsyncClient(**client_kwargs)
    
    try:
        # Connect to the YouTube CDN URL
        req = client.build_request("GET", decoded_url, headers=headers)
        resp = await client.send(req, stream=True)
        
        # Check if the CDN returned success or partial content
        if resp.status_code not in (200, 206):
            await resp.aclose()
            await client.aclose()
            logger.error(f"YouTube CDN returned status code {resp.status_code}: {resp.reason_phrase}")
            raise HTTPException(
                status_code=resp.status_code, 
                detail=f"YouTube CDN returned error: {resp.reason_phrase}"
            )
            
        # Setup headers for the response to the client
        response_headers = {
            "Content-Disposition": f'attachment; filename="{filename}"',
            # Prevent browser caching of streams
            "Cache-Control": "no-cache"
        }
        
        # Forward key headers from YouTube CDN
        forward_headers = [
            "Content-Type", 
            "Content-Length", 
            "Content-Range", 
            "Accept-Ranges",
            "ETag",
            "Last-Modified"
        ]
        for h in forward_headers:
            if h in resp.headers:
                response_headers[h] = resp.headers[h]
                
        # Generator function to stream chunks without buffering entire file in memory
        async def stream_chunks():
            try:
                # 512KB chunks for smooth streaming
                async for chunk in resp.aiter_bytes(chunk_size=524288):
                    yield chunk
            except Exception as stream_err:
                logger.error(f"Error streaming response to client: {str(stream_err)}")
            finally:
                await resp.aclose()
                await client.aclose()
                
        return StreamingResponse(
            stream_chunks(),
            status_code=resp.status_code,
            headers=response_headers
        )
        
    except httpx.RequestError as exc:
        await client.aclose()
        logger.error(f"HTTP request failed: {exc}")
        raise HTTPException(status_code=502, detail=f"Failed to communicate with YouTube CDN: {str(exc)}")
    except Exception as e:
        await client.aclose()
        logger.error(f"Unexpected error in proxy download: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Proxy error: {str(e)}")
