#!/usr/bin/env bash
# OpenClaw - 通用 AI 助手（Docker 服务）
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_DIR/docker/docker-compose.yml"

echo "[+] Starting OpenClaw..."
docker compose -f "$COMPOSE_FILE" --profile full up -d --build openclaw 2>&1 | tail -5
echo "[✓] OpenClaw daemon started."
