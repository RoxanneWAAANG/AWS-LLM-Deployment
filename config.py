import os

class Config:
    # Model settings
    MODEL_NAME = "microsoft/DialoGPT-small"  # Lightweight model for quick deployment
    MAX_LENGTH = 100
    TEMPERATURE = 0.7
    
    # Cache settings
    CACHE_TTL = 3600  # 1 hour
    USE_REDIS = os.getenv("USE_REDIS", "false").lower() == "true"
    REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")
    
    # API settings
    HOST = "0.0.0.0"
    PORT = 8000
    
    # Performance
    MAX_CONCURRENT_REQUESTS = 10