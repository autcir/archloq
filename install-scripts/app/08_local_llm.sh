#!/bin/bash
# =============================================================================
# 08 - Local LLM Installation (Ollama + llama.cpp)
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"

say "Installing Local LLM stack..."

# Ollama
if [[ "${LOQ_ENABLE_OLLAMA:-1}" == "1" ]]; then
    curl -fsSL https://ollama.com/install.sh | sh
    ok "Ollama installed"
fi

# llama.cpp
if [[ "${LOQ_ENABLE_LLAMA_CPP:-1}" == "1" ]]; then
    cd /tmp
    git clone https://github.com/ggerganov/llama.cpp.git
    cd llama.cpp
    cmake -DLLAMA_CUDA=on -B build
    cmake --build build -j$(nproc)
    cmake --install build
    ok "llama.cpp built with CUDA"
fi

# Open WebUI
if [[ "${LOQ_ENABLE_OPEN_WEBUI:-0}" == "1" ]]; then
    docker run -d -p 3000:8080 --add-host=host.docker.internal:host-gateway openwebui/open-webui
    ok "Open WebUI installed"
fi

ok "Local LLM stack ready"
ok "Usage: ollama run llama3  or  llama-cli --model /path/to/model"