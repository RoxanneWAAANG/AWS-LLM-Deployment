#!/bin/bash

echo "Starting Open Source LLM Deployment..."

# Install dependencies
pip install -r requirements.txt

# Start Redis (if using Docker)
if command -v docker &> /dev/null; then
    echo "Starting Redis container..."
    docker run -d --name llm-redis -p 6379:6379 redis:alpine
    export USE_REDIS=true
fi

# Run the API
echo "Starting LLM API..."
python app.py