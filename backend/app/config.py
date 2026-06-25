from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # API Settings
    APP_NAME: str = "YouTube Video Downloader API"
    DEBUG: bool = False
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    
    # CORS Settings
    ALLOWED_ORIGINS: list[str] = ["*"]
    
    # Proxy configuration for yt-dlp (optional)
    # E.g. "socks5://127.0.0.1:1080" or "http://username:password@proxy:port"
    HTTP_PROXY: str | None = None
    
    # Base URL for the service. If None, it will be dynamically generated based on incoming request headers.
    BASE_URL: str | None = None

    class Config:
        env_file = ".env"

settings = Settings()
