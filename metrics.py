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
        self.max_requests = 1000  # Keep last 1000 requests
    
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
        
        recent = self.requests[-100:]  # Last 100 requests
        
        return {
            "total_requests": len(self.requests),
            "avg_response_time": sum(r.response_time for r in recent) / len(recent),
            "cache_hit_rate": sum(1 for r in recent if r.cache_hit) / len(recent),
            "avg_memory_usage": sum(r.memory_usage for r in recent) / len(recent),
            "avg_cpu_usage": sum(r.cpu_usage for r in recent) / len(recent),
            "latest_request": asdict(recent[-1]) if recent else None
        }

metrics_collector = MetricsCollector()