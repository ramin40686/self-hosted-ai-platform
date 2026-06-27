# AI Platform

A self-hosted AI platform built with Docker, vLLM, LiteLLM and Open WebUI.

The goal of this project is to provide a production-ready local AI platform capable of serving multiple LLMs through a unified OpenAI-compatible API.

---

# Features

- Docker-based deployment
- vLLM inference server
- Multiple models served simultaneously
- LiteLLM as OpenAI-compatible gateway
- Open WebUI integration
- Hugging Face model management
- Ready for RAG
- Ready for Embedding models
- Ready for Vision models
- Ready for Speech models

---

# Architecture

```
                    ┌─────────────────────┐
                    │    Open WebUI       │
                    │     Port 8080       │
                    └──────────┬──────────┘
                               │
                               │ OpenAI API
                               ▼
                    ┌─────────────────────┐
                    │      LiteLLM        │
                    │     Port 4000       │
                    └──────┬───────┬──────┘
                           │       │
              ┌────────────┘       └────────────┐
              ▼                                 ▼

     ┌────────────────┐               ┌────────────────┐
     │  vLLM Qwen7B   │               │ vLLM Qwen1.5B  │
     │   Port 8000    │               │   Port 8000    │
     └────────────────┘               └────────────────┘

```

---

# Project Structure

```
ai-platform/

├── docker/
│   ├── compose.inference.yml
│   ├── compose.litellm.yml
│   └── compose.openwebui.yml
│
├── models/
│   ├── chat/
│   ├── coder/
│   ├── vision/
│   ├── speech/
│   ├── embedding/
│   └── reranker/
│
├── datasets/
├── embeddings/
├── backups/
├── logs/
└── scripts/
```

---

# Installed Services

| Service | Purpose | Port |
|----------|---------|------|
| vLLM | Model Inference | Internal |
| LiteLLM | OpenAI API Gateway | 4000 |
| Open WebUI | Web Interface | 8080 |

---

# Current Models

| Alias | Model |
|--------|------|
| qwen15 | Qwen2.5-1.5B-Instruct |
| qwen7b | Qwen2.5-7B-Instruct |

---

# Starting the Platform

```
cd /home/ramin/ai-platform/docker

docker compose \
-f compose.inference.yml \
-f compose.litellm.yml \
-f compose.openwebui.yml \
up -d
```

---

# Stop

```
docker compose \
-f compose.inference.yml \
-f compose.litellm.yml \
-f compose.openwebui.yml \
down
```

---

# Verify Services

Containers

```
docker ps
```

LiteLLM

```
curl http://localhost:4000/health
```

Models

```
curl http://localhost:4000/v1/models \
-H "Authorization: Bearer supersecretkey"
```

Open WebUI

```
http://localhost:8080
```

---

# OpenAI Compatible API

Example

```bash
curl http://localhost:4000/v1/chat/completions \
-H "Authorization: Bearer supersecretkey" \
-H "Content-Type: application/json" \
-d '{
  "model":"qwen7b",
  "messages":[
    {
      "role":"user",
      "content":"Hello"
    }
  ]
}'
```

---

# Model Storage

Models are stored in

```
/home/ramin/ai-platform/models
```

Organized by category

```
chat/
coder/
vision/
speech/
embedding/
reranker/
```

---

# Downloading Models

The project includes a helper script.

```
scripts/download-models.sh
```

Usage

```
source /home/ramin/ai-platform/.env

export HF_TOKEN

./scripts/download-models.sh
```

The downloader automatically

- creates folders
- resumes interrupted downloads
- skips completed files
- stores models in the proper category

---

# Adding a New Model

1. Download the model

2. Add a new vLLM service

Example

```
vllm-gemma
```

3. Register the model in LiteLLM

```
model_list:
```

4. Restart

```
docker compose up -d
```

---

# Updating Models

Simply run the download script again.

Hugging Face downloads only missing or changed files.

---

# Useful Commands

Containers

```
docker ps
```

GPU

```
nvidia-smi
```

Disk

```
df -h
```

Model Size

```
du -sh models/*
```

Logs

```
docker logs -f open-webui

docker logs -f litellm

docker logs -f vllm-qwen7b
```

---

# Technologies

- Docker
- NVIDIA Container Toolkit
- vLLM
- LiteLLM
- Open WebUI
- Hugging Face
- Qwen
- Llama
- Gemma

---
#Current Features

✅ Automatic Model Registry
✅ Automatic Compose Generation
✅ Automatic LiteLLM Configuration
✅ Multi GPU Scheduling

# Roadmap

- [x] Docker Infrastructure
- [x] vLLM
- [x] LiteLLM
- [x] Open WebUI
- [x] Multiple LLMs
- [x] Automatic Model Registry
- [x] Automatic Compose Generation 
- [x] Automatic LiteLLM Configuration
- [x] Multi GPU Scheduling
- [ ] Embedding Server
- [ ] Reranker
- [ ] RAG Pipeline
- [ ] Whisper API
- [ ] Vision Models
- [ ] Text-to-Speech
- [ ] Monitoring
- [ ] Reverse Proxy
- [ ] Authentication
- [ ] HTTPS
- [ ] Backup Automation

---

# License

MIT
