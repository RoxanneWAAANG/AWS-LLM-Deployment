# Create a simpler requirements.txt without torch first
cat > requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn==0.24.0
transformers==4.36.0
psutil==5.9.6
pydantic==2.5.0
python-multipart==0.0.6
EOF

# Install PyTorch CPU version separately with the correct command
pip3 install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Then install the rest
pip3 install --no-cache-dir -r requirements.txt

# Now create the simple app
cat > app.py << 'EOF'
import time
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch

# Simple in-memory cache
cache = {}
metrics = {"requests": 0, "cache_hits": 0}

# Initialize FastAPI
app = FastAPI(title="Simple LLM API", version="1.0.0")

# Global variables
tokenizer = None
model = None

@app.on_event("startup")
async def load_model():
    global tokenizer, model
    print("Loading GPT-2 model...")
    tokenizer = AutoTokenizer.from_pretrained("gpt2")
    model = AutoModelForCausalLM.from_pretrained("gpt2")
    tokenizer.pad_token = tokenizer.eos_token
    print("Model loaded successfully!")

class GenerateRequest(BaseModel):
    text: str
    max_length: int = 30

@app.get("/")
async def root():
    return {
        "message": "Simple LLM API is running!", 
        "model": "GPT-2",
        "docs": "Visit /docs for API documentation"
    }

@app.post("/generate")
async def generate_text(request: GenerateRequest):
    start_time = time.time()
    metrics["requests"] += 1
    
    # Check cache
    if request.text in cache:
        metrics["cache_hits"] += 1
        return {
            "response": cache[request.text],
            "cached": True,
            "response_time": time.time() - start_time
        }
    
    try:
        # Tokenize input
        inputs = tokenizer.encode(request.text, return_tensors="pt")
        
        # Generate response
        with torch.no_grad():
            outputs = model.generate(
                inputs,
                max_length=min(inputs.shape[1] + request.max_length, 100),
                temperature=0.7,
                do_sample=True,
                pad_token_id=tokenizer.eos_token_id
            )
        
        # Decode and clean response
        full_response = tokenizer.decode(outputs[0], skip_special_tokens=True)
        response = full_response[len(request.text):].strip()
        
        # Cache the response
        cache[request.text] = response
        
        return {
            "response": response,
            "cached": False,
            "response_time": time.time() - start_time
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Generation failed: {str(e)}")

@app.get("/metrics")
async def get_metrics():
    cache_hit_rate = metrics["cache_hits"] / metrics["requests"] if metrics["requests"] > 0 else 0
    return {
        "total_requests": metrics["requests"],
        "cache_hits": metrics["cache_hits"], 
        "cache_hit_rate": round(cache_hit_rate, 2),
        "cached_items": len(cache),
        "model": "GPT-2",
        "status": "running"
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy", 
        "model": "GPT-2",
        "torch_version": torch.__version__
    }

# Add a cache management endpoint
@app.delete("/cache")
async def clear_cache():
    cache.clear()
    return {"message": "Cache cleared", "cached_items": len(cache)}

if __name__ == "__main__":
    import uvicorn
    print("Starting Simple LLM API on port 8000...")
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

# Start the API
echo "Starting the API server..."
python3 app.py