#!/usr/bin/env bash
# 用途：在 Docker 容器里启动 Dulus CLI Agent。
# 默认使用 Ollama 的 qwen2.5-coder:7b 模型，并把当前目录挂载进容器。
# 适合测试本地 CLI Agent 能力或在当前目录里执行代码任务。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"

WORK_DIR="${1:-$(pwd)}"
shift 2>/dev/null || true

exec docker compose -f "$COMPOSE_FILE" --profile cli run --rm \
    -v "$WORK_DIR:$WORK_DIR" -w "$WORK_DIR" \
    dulus --model ollama/qwen2.5-coder:7b "$@"
