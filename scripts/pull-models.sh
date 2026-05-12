#!/usr/bin/env bash
# 拉取推荐模型到 Ollama 容器
set -euo pipefail

OLLAMA_CTR="${OLLAMA_CTR:-agent-ollama}"

DEFAULT_MODELS=( "qwen2.5-coder:7b" "nomic-embed-text" )
LIGHT_MODELS=(  "qwen2.5-coder:7b" "nomic-embed-text" )
FULL_MODELS=(   "qwen2.5-coder:32b" "deepseek-r1:32b" "qwen2.5-coder:14b" "nomic-embed-text" )

MODE="${1:-default}"
case "$MODE" in
    light) MODELS=("${LIGHT_MODELS[@]}") ;;
    full)  MODELS=("${FULL_MODELS[@]}") ;;
    *)     MODELS=("${DEFAULT_MODELS[@]}") ;;
esac

for model in "${MODELS[@]}"; do
    echo "[+] Pulling $model..."
    docker exec "$OLLAMA_CTR" ollama pull "$model"
done

echo ""
echo "[✓] Done. Models:"
docker exec "$OLLAMA_CTR" ollama list
