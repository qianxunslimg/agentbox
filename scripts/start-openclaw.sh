#!/usr/bin/env bash
# 用途：启动 OpenClaw 相关服务。
# 会启动/连接 Ollama、SearXNG 和 OpenClaw，并确保 OpenClaw 容器能用 ollama 这个网络别名访问本地模型。
# 这是日常启动 OpenClaw 的推荐入口。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
COMPOSE_PROJECT_NAME="$(basename "$PROJECT_DIR")"
COMPOSE_NETWORK="${COMPOSE_PROJECT_NAME}_default"

echo "[+] Starting OpenClaw..."
docker start agent-ollama >/dev/null 2>&1 || docker compose -f "$COMPOSE_FILE" up -d ollama
docker compose -f "$COMPOSE_FILE" --profile full up -d searxng openclaw 2>&1 | tail -8
docker network connect --alias ollama "$COMPOSE_NETWORK" agent-ollama >/dev/null 2>&1 || true
echo "[✓] OpenClaw daemon started."
