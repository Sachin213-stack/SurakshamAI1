from functools import lru_cache
from pydantic_settings import BaseSettings
from pydantic import Field


class Settings(BaseSettings):
    # App
    app_name: str = "Sentinel-Agent"
    app_version: str = "1.0.0"
    environment: str = Field(default="production", env="ENVIRONMENT")
    debug: bool = Field(default=False, env="DEBUG")

    # Security
    api_key_header: str = "X-API-Key"
    # Stored as comma-separated string in .env, e.g. API_KEYS=key1,key2
    api_keys: str = Field(default="", env="API_KEYS")

    @property
    def api_key_list(self) -> list[str]:
        return [k.strip() for k in self.api_keys.split(",") if k.strip()]

    # Groq
    groq_api_key: str = Field(..., env="GROQ_API_KEY")
    groq_model: str = Field(default="llama-3.3-70b-versatile", env="GROQ_MODEL")
    groq_max_tokens: int = Field(default=150, env="GROQ_MAX_TOKENS")
    groq_temperature: float = Field(default=0.1, env="GROQ_TEMPERATURE")
    groq_timeout: int = Field(default=10, env="GROQ_TIMEOUT")
    groq_max_retries: int = Field(default=3, env="GROQ_MAX_RETRIES")

    # Pinecone
    pinecone_api_key: str = Field(default="", env="PINECONE_API_KEY")
    pinecone_index: str = Field(default="sentinel-patterns", env="PINECONE_INDEX")
    pinecone_cloud: str = Field(default="aws", env="PINECONE_CLOUD")
    pinecone_region: str = Field(default="us-east-1", env="PINECONE_REGION")

    # Rate Limiting
    rate_limit_requests: int = Field(default=60, env="RATE_LIMIT_REQUESTS")
    rate_limit_window: int = Field(default=60, env="RATE_LIMIT_WINDOW")  # seconds

    # Fraud thresholds
    overlay_threshold: int = Field(default=50, env="OVERLAY_THRESHOLD")
    block_threshold: int = Field(default=80, env="BLOCK_THRESHOLD")

    # WebSocket
    ws_ping_interval: int = Field(default=30, env="WS_PING_INTERVAL")
    ws_max_connections: int = Field(default=100, env="WS_MAX_CONNECTIONS")

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

    @property
    def is_production(self) -> bool:
        return self.environment == "production"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
