#!/usr/bin/env bash
# 用途：统一启动/停止这个项目里的 Docker 服务。
# 支持启动完整服务栈，也支持单独启动 open-webui、localagi、openagentd 等服务。
# 适合日常管理非 OpenClaw 专属的整体 agent 平台。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"

compose() {
    docker compose -f "$COMPOSE_FILE" "$@"
}

service_name() {
    case "${1:-}" in
        "" ) echo "" ;;
        webui|open-webui) echo "open-webui" ;;
        agent|localagi) echo "localagi" ;;
        oad|openagentd) echo "openagentd" ;;
        * ) echo "$1" ;;
    esac
}

case "${1:-up}" in
    up)
        echo "[+] Starting Open WebUI + LocalAGI + OpenAgentd..."
        compose --profile full up -d
        echo ""
        echo "[✓] Open WebUI: http://localhost:3000"
        echo "[✓] LocalAGI:   http://localhost:8080"
        echo "[✓] OpenAgentd: http://localhost:4082"
        ;;
    webui)
        echo "[+] Starting Open WebUI..."
        compose up -d open-webui
        echo "[✓] Open WebUI: http://localhost:3000"
        ;;
    agent)
        echo "[+] Starting LocalAGI + OpenAgentd..."
        compose --profile agent up -d localagi openagentd
        echo "[✓] LocalAGI:   http://localhost:8080"
        echo "[✓] OpenAgentd: http://localhost:4082"
        ;;
    full)
        compose --profile full up -d --build
        ;;
    down)
        compose --profile full down
        echo "[✓] All services stopped."
        ;;
    logs)
        service="$(service_name "${2:-}")"
        if [[ -n "$service" ]]; then
            compose logs -f "$service"
        else
            compose logs -f
        fi
        ;;
    restart)
        service="$(service_name "${2:-}")"
        if [[ -n "$service" ]]; then
            compose --profile full restart "$service"
        else
            compose --profile full restart
        fi
        ;;
    config)
        compose --profile full config
        ;;
    *)
        echo "Usage: $0 {up|webui|agent|full|down|logs|restart|config}"
        ;;
esac
