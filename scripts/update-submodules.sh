#!/usr/bin/env bash
# 用途：把项目里的 Git submodule 更新到远端最新版本。
# 运行后只更新工作区，不会自动提交；需要人工检查 diff 后再 commit。
# 适合明确要同步上游子模块版本时使用，平时不要随手运行。
set -euo pipefail

echo "[+] Updating all submodules to latest remote..."
git submodule update --remote --recursive

echo "[+] Submodule status:"
git submodule status

echo ""
echo "[✓] Updated. Review changes and commit:"
echo "    git add frameworks/ && git commit -m 'Update submodules to latest'"
