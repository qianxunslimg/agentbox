#!/usr/bin/env bash
# Aider - AI 结对编程（Docker 内运行）
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_DIR/docker/docker-compose.yml"

WORK_DIR="${1:-$(pwd)}"
shift 2>/dev/null || true

exec docker compose -f "$COMPOSE_FILE" --profile cli run --rm \
    -v "$WORK_DIR:$WORK_DIR" -w "$WORK_DIR" \
    -e OLLAMA_API_BASE=http://ollama:11434 \
    aider "$@"
