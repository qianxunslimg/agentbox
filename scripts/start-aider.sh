#!/usr/bin/env bash
# 用途：在 Docker 容器里启动 Aider AI 结对编程工具。
# 默认把当前目录挂载进容器，也可以把目标工作目录作为第一个参数传入。
# 适合临时用 Aider 修改当前项目或其他代码目录。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"

WORK_DIR="${1:-$(pwd)}"
shift 2>/dev/null || true

exec docker compose -f "$COMPOSE_FILE" --profile cli run --rm \
    -v "$WORK_DIR:$WORK_DIR" -w "$WORK_DIR" \
    aider "$@"
