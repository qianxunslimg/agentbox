#!/usr/bin/env bash
# Update all submodules to latest
set -euo pipefail

echo "[+] Updating all submodules to latest remote..."
git submodule update --remote --recursive

echo "[+] Submodule status:"
git submodule status

echo ""
echo "[✓] Updated. Review changes and commit:"
echo "    git add frameworks/ && git commit -m 'Update submodules to latest'"
