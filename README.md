# AWS LLM Deployment

A complete open source language model deployment solution on AWS infrastructure with REST API, caching, and performance monitoring.

## Overview

This project demonstrates end-to-end deployment of an open source language model (GPT-2) on AWS EC2 with a production-ready API wrapper. The system includes automated deployment scripts, intelligent caching, real-time metrics, and comprehensive documentation.

## Features

- **Automated AWS Deployment**: Script-driven EC2 instance provisioning with security group management
- **REST API Interface**: FastAPI-based web service with automatic documentation generation
- **Intelligent Caching**: In-memory response caching for improved performance
- **Performance Monitoring**: Real-time metrics tracking and system health monitoring
- **Production Ready**: Error handling, logging, and scalable architecture
- **Interactive Documentation**: Auto-generated API docs with live testing interface

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Client App    │    │   AWS EC2       │    │   GPT-2 Model   │
│                 │◄──►│   FastAPI       │◄──►│   Transformers  │
│   HTTP/REST     │    │   + Caching     │    │   Library       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │    Metrics      │
                       │   Monitoring    │
                       └─────────────────┘
```

## Requirements

- AWS CLI configured with appropriate permissions
- Python 3.8+
- SSH key pair for EC2 access
- 8GB+ available disk space on EC2 instance

## Quick Start

### 1. Deploy Infrastructure

```bash
# Clone the repository
git clone <repository-url>
cd AWS-LLM-Deployment

# Navigate to deployment directory
cd aws

# Create SSH key pair
aws ec2 create-key-pair \
    --key-name llm-deployment-key \
    --query 'KeyMaterial' \
    --output text > llm-deployment-key.pem

# Set proper permissions
chmod 400 llm-deployment-key.pem

# Deploy EC2 instance
./deploy-aws.sh
```

### 2. Set Up Application

SSH into your EC2 instance using the details from `instance-info.txt`:

```bash
ssh -i llm-deployment-key.pem ec2-user@<PUBLIC_IP>
```

Install and run the application:

```bash
# Update system
sudo yum update -y
sudo yum install -y python3 python3-pip

# Create project directory
mkdir llm-project && cd llm-project

# Install dependencies
pip3 install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
pip3 install --no-cache-dir fastapi uvicorn transformers psutil pydantic python-multipart

# Create and run the application
python3 app.py
```

### 3. Access the API

- **API Base**: `http://<PUBLIC_IP>:8000`
- **Interactive Docs**: `http://<PUBLIC_IP>:8000/docs`
- **Health Check**: `http://<PUBLIC_IP>:8000/health`

## API Usage

### Generate Text

```bash
curl -X POST "http://<PUBLIC_IP>:8000/generate" \
     -H "Content-Type: application/json" \
     -d '{
       "text": "The future of artificial intelligence is",
       "max_length": 50
     }'
```

Response:
```json
{
  "response": "going to be very exciting and transformative...",
  "cached": false,
  "response_time": 1.23
}
```

### Get Performance Metrics

```bash
curl http://<PUBLIC_IP>:8000/metrics
```

Response:
```json
{
  "total_requests": 15,
  "cache_hits": 7,
  "cache_hit_rate": 0.47,
  "cached_items": 8,
  "model": "GPT-2",
  "status": "running"
}
```

### Health Check

```bash
curl http://<PUBLIC_IP>:8000/health
```

## Project Structure

```
AWS-LLM-Deployment/
├── aws/
│   ├── deploy-aws.sh          # AWS deployment automation
│   ├── config.sh              # AWS configuration
│   └── instance-info.txt      # Deployment details
├── app.py                     # Main FastAPI application
├── config.py                  # Application configuration
├── cache.py                   # Caching implementation
├── metrics.py                 # Performance monitoring
├── requirements.txt           # Python dependencies
├── Dockerfile                 # Container configuration
├── docker-compose.yml         # Multi-container setup
└── README.md                  # Project documentation
```

## Configuration

### Environment Variables

- `MODEL_NAME`: Hugging Face model identifier (default: "gpt2")
- `MAX_LENGTH`: Maximum generation length (default: 50)
- `TEMPERATURE`: Generation randomness (default: 0.7)
- `HOST`: API server host (default: "0.0.0.0")
- `PORT`: API server port (default: 8000)

### Model Options

The system supports various Hugging Face models:
- `gpt2` (default) - 124M parameters, fast
- `gpt2-medium` - 355M parameters, better quality
- `gpt2-large` - 774M parameters, high quality
- `microsoft/DialoGPT-small` - Conversational model

## Performance Optimization

### Caching Strategy

- **In-Memory Cache**: Stores recent responses for identical inputs
- **Automatic Expiration**: Configurable TTL for cache entries
- **Hit Rate Monitoring**: Real-time cache effectiveness metrics

### Resource Management

- **CPU-Only Inference**: Optimized for cost-effective deployment
- **Memory Monitoring**: Tracks system resource usage
- **Request Throttling**: Configurable concurrent request limits

## Monitoring and Metrics

The system provides comprehensive monitoring through the `/metrics` endpoint:

- **Request Volume**: Total API calls processed
- **Cache Performance**: Hit rate and efficiency metrics
- **Response Times**: Average processing duration
- **System Health**: Memory and CPU utilization
- **Model Status**: Loading state and readiness

## Deployment Options

### Local Development

```bash
# Run locally
python3 app.py

# Access at http://localhost:8000
```

### Docker Deployment

```bash
# Build and run with Docker
docker-compose up -d

# Access at http://localhost:8000
```

### AWS Production

Follow the Quick Start guide for full AWS deployment with EC2.

## Troubleshooting

### Common Issues

**Model Loading Errors**
- Ensure sufficient memory (4GB+ recommended)
- Check internet connectivity for model download
- Verify Hugging Face model name spelling

**API Connection Issues**
- Confirm EC2 security groups allow port 8000
- Check instance public IP address
- Verify SSH key permissions (chmod 400)

**Performance Issues**
- Monitor memory usage via `/metrics`
- Consider smaller model variants
- Enable caching for repeated requests
