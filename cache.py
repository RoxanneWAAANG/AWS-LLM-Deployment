import json
import hashlib
from typing import Optional
import redis
from config import Config

class Cache:
    def __init__(self):
        if Config.USE_REDIS:
            self.redis_client = redis.from_url(Config.REDIS_URL)
            self.cache_type = "redis"
        else:
            self.memory_cache = {}
            self.cache_type = "memory"
    
    def _get_key(self, text: str) -> str:
        return hashlib.md5(text.encode()).hexdigest()
    
    def get(self, text: str) -> Optional[str]:
        key = self._get_key(text)
        
        if self.cache_type == "redis":
            try:
                cached = self.redis_client.get(key)
                return cached.decode() if cached else None
            except:
                return None
        else:
            return self.memory_cache.get(key)
    
    def set(self, text: str, response: str):
        key = self._get_key(text)
        
        if self.cache_type == "redis":
            try:
                self.redis_client.setex(key, Config.CACHE_TTL, response)
            except:
                pass
        else:
            self.memory_cache[key] = response

cache = Cache()