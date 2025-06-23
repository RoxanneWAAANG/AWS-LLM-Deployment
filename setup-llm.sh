#!/bin/bash

# Create the LLM project files on EC2 instance
echo "Setting up LLM project..."

# Create requirements.txt
cat > requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn==0.24.0
transformers==4.36.0
torch==2.1.0
redis==5.0.1
psutil==5.9.6
pydantic==2.5.0
python-multipart==0.0.6
EOF

# Create config.py
cat > config.py << 'EOF'
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
EOF

# Create cache.py
cat > cache.py << 'EOF'
import json
import hashlib
from typing import Optional

class Cache:
    def __init__(self):
        self.memory_cache = {}
        self.cache_type = "memory"
    
    def _get_key(self, text: str) -> str:
        return hashlib.md5(text.encode()).hexdigest()
    
    def get(self, text: str) -> Optional[str]:
        key = self._get_key(text)
        return self.memory_cache.get(key)
    
    def set(self, text: str, response: str):
        key = self._get_key(text)
        self.memory_cache[key] = response

cache = Cache()
EOF

# Create metrics.py
cat > metrics.py << 'EOF'
import time
import psutil
from typing import Dict, List
from dataclasses import dataclass, asdict

@dataclass
class RequestMetrics:
    timestamp: float
    response_time: float
    input_length: int
    output_length: int
    cache_hit: bool
    memory_usage: float
    cpu_usage: float

class MetricsCollector:
    def __init__(self):
        self.requests: List[RequestMetrics] = []
        self.max_requests = 1000
    
    def record_request(self, start_time: float, input_text: str, 
                      output_text: str, cache_hit: bool):
        response_time = time.time() - start_time
        
        metrics = RequestMetrics(
            timestamp=time.time(),
            response_time=response_time,
            input_length=len(input_text),
            output_length=len(output_text),
            cache_hit=cache_hit,
            memory_usage=psutil.virtual_memory().percent,
            cpu_usage=psutil.cpu_percent()
        )
        
        self.requests.append(metrics)
        if len(self.requests) > self.max_requests:
            self.requests.pop(0)
    
    def get_stats(self) -> Dict:
        if not self.requests:
            return {"message": "No requests recorded"}
        
        recent = self.requests[-100:]
        
        return {
            "total_requests": len(self.requests),
            "avg_response_time": sum(r.response_time for r in recent) / len(recent),
            "cache_hit_rate": sum(1 for r in recent if r.cache_hit) / len(recent),
            "avg_memory_usage": sum(r.memory_usage for r in recent) / len(recent),
            "avg_cpu_usage": sum(r.cpu_usage for r in recent) / len(recent),
            "latest_request": asdict(recent[-1]) if recent else None
        }

metrics_collector = MetricsCollector()
EOF

# Create app.py
cat > app.py << 'EOF'
import time
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch

from config import Config
from cache import cache
from metrics import metrics_collector

# Initialize FastAPI
app = FastAPI(title="Open Source LLM API", version="1.0.0")

# Global variables for model (loaded on startup)
tokenizer = None
model = None

@app.on_event("startup")
async def load_model():
    global tokenizer, model
    print("Loading model...")
    tokenizer = AutoTokenizer.from_pretrained(Config.MODEL_NAME)
    model = AutoModelForCausalLM.from_pretrained(Config.MODEL_NAME)
    
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
    
    print("Model loaded successfully!")

class GenerateRequest(BaseModel):
    text: str
    max_length: int = Config.MAX_LENGTH
    temperature: float = Config.TEMPERATURE

class GenerateResponse(BaseModel):
    response: str
    cached: bool
    response_time: float

@app.get("/")
async def root():
    return {"message": "Open Source LLM API is running!"}

@app.post("/generate", response_model=GenerateResponse)
async def generate_text(request: GenerateRequest):
    start_time = time.time()
    
    # Check cache first
    cached_response = cache.get(request.text)
    if cached_response:
        response_time = time.time() - start_time
        metrics_collector.record_request(start_time, request.text, 
                                       cached_response, cache_hit=True)
        return GenerateResponse(
            response=cached_response,
            cached=True,
            response_time=response_time
        )
    
    try:
        # Tokenize input
        inputs = tokenizer.encode(request.text, return_tensors="pt", 
                                padding=True, truncation=True)
        
        # Generate response
        with torch.no_grad():
            outputs = model.generate(
                inputs,
                max_length=min(request.max_length, inputs.shape[1] + 50),
                temperature=request.temperature,
                do_sample=True,
                pad_token_id=tokenizer.eos_token_id
            )
        
        # Decode response
        response = tokenizer.decode(outputs[0], skip_special_tokens=True)
        response = response[len(request.text):].strip()
        
        # Cache the response
        cache.set(request.text, response)
        
        response_time = time.time() - start_time
        metrics_collector.record_request(start_time, request.text, 
                                       response, cache_hit=False)
        
        return GenerateResponse(
            response=response,
            cached=False,
            response_time=response_time
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Generation failed: {str(e)}")

@app.get("/metrics")
async def get_metrics():
    return metrics_collector.get_stats()

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "model": Config.MODEL_NAME,
        "cache_type": cache.cache_type
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host=Config.HOST, port=Config.PORT)
EOF

echo "Installing dependencies..."
pip3 install -r requirements.txt

echo "Starting LLM API..."
echo "API will be available at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8000"
python3 app.py