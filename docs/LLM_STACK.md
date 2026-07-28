# Local LLM Stack

## Overview

LOQ supports three local LLM runtimes optimized for RTX 5060 Blackwell:

1. **Ollama** - Easy-to-use runtime
2. **llama.cpp** - GPU-accelerated inference
3. **Open WebUI** - Web interface

---

## Ollama

### Install

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### Run

```bash
# Start server
ollama serve &

# Pull a model
ollama pull llama3

# Run inference
ollama run llama3
```

### GPU Support

Ollama automatically detects NVIDIA GPU:

```bash
# Check GPU usage
nvidia-smi

# Ollama uses CUDA 12.x
```

### Models

```bash
# List available models
ollama list

# Pull popular models
ollama pull llama3
ollama pull qwen2.5:7b
ollama pull codellama:7b
```

---

## llama.cpp

### Build with CUDA

```bash
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp

# Build with CUDA
cmake -DLLAMA_CUDA=on -B build
cmake --build build -j$(nproc)

# Install
sudo cmake --install build
```

### Usage

```bash
# Quantize model
./build/bin/llama-cli --model /path/to/model.gguf --q80

# Run with GPU
./build/bin/llama-cli --model model-q80.gguf --gpu-layers 99
```

### CUDA Backend

llama.cpp supports:
- CUDA 12.x
- Automatic layer offloading
- KV cache quantization

---

## Open WebUI

### Install

```bash
# Using Docker
docker run -d -p 3000:8080 \
  --add-host=host.docker.internal:host-gateway \
  --restart=always \
  -v open-webui:/app/backend/data \
  openwebui/open-webui:latest
```

### Configure

```bash
# Set environment
export OPENAI_API_BASE_URL=http://localhost:11434/v1

# Access web UI
http://localhost:3000
```

### Connect to Ollama

```bash
# Open WebUI will auto-detect Ollama
# If not, configure in Settings → Models
```

---

## Performance Tuning

### Ollama

```bash
# Set number of GPU layers
export OLLAMA_GPU_LAYERS=99

# Set number of threads
export OLLAMA_NUM_THREADS=$(nproc)
```

### llama.cpp

```bash
# GPU layers (auto-detect)
--gpu-layers 99

# Context size
--ctx-size 4096

# Batch size
--batch-size 512
```

### Memory Management

```bash
# Check VRAM usage
nvidia-smi

# Use smaller models for VRAM constraints
# 7B models: ~8GB VRAM
# 13B models: ~16GB VRAM
# 30B models: ~32GB VRAM
```

---

## Troubleshooting

### Ollama Not Using GPU

```bash
# Check CUDA
nvidia-smi

# Restart Ollama
pkill ollama
ollama serve &

# Check logs
tail -f ~/.ollama/logs/server.log
```

### llama.cpp CUDA Errors

```bash
# Check CUDA version
nvcc --version

# Rebuild with correct CUDA
cmake -DLLAMA_CUDA=on -B build -S .
```

### Low Performance

```bash
# Check model size vs VRAM
# Use quantized models (Q8_0, Q5_K_M)

# Reduce context size
--ctx-size 2048

# Reduce batch size
--batch-size 256
```

---

## Model Recommendations

| Model | Size | VRAM | Use Case |
|-------|------|------|----------|
| Llama3 8B | 8B | 8GB | General chat |
| Qwen2.5 7B | 7B | 8GB | Coding |
| CodeLlama 7B | 7B | 8GB | Programming |
| Llama3 70B | 70B | 64GB+ | High-quality |