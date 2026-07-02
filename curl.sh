curl -X POST "http://localhost:30000/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "/ssd3/models/Qwen3.5-27B",
    "messages": [
      {
        "role": "user",
        "content": "介绍一下你自己"
      }
    ],
    "temperature": 0.7,
    "max_tokens": 1024,
    "stream": false
  }'