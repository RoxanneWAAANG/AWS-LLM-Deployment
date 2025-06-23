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

# Load model (happens once at startup)
print("Loading model...")
tokenizer = AutoTokenizer.from_pretrained(Config.MODEL_NAME)
model = AutoModelForCausalLM.from_pretrained(Config.MODEL_NAME)

# Add padding token if not present
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
        # Remove input text from response
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