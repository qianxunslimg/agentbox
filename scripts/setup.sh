#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo "  Local Agent Platform - Environment Setup"
echo "========================================="

# Detect OS
OS="$(uname -s)"
echo "[+] OS: $OS"

# Check / Install Ollama
if command -v ollama &>/dev/null; then
    echo "[✓] Ollama found: $(ollama --version 2>/dev/null || echo 'installed')"
else
    echo "[!] Ollama not found. Installing..."
    if [[ "$OS" == "Linux" ]]; then
        curl -fsSL https://ollama.com/install.sh | sh
    elif [[ "$OS" == "Darwin" ]]; then
        brew install ollama
    else
        echo "[-] Unsupported OS for auto-install. Please install Ollama manually."
    fi
fi

# Check / Install Python deps
if command -v python3 &>/dev/null; then
    echo "[✓] Python: $(python3 --version)"
else
    echo "[-] Python3 required. Install via your package manager."
fi

# Check / Install Node.js
if command -v node &>/dev/null; then
    echo "[✓] Node.js: $(node --version)"
else
    echo "[-] Node.js not found."
fi

# Check / Install Docker
if command -v docker &>/dev/null; then
    echo "[✓] Docker: $(docker --version 2>/dev/null | head -1)"
else
    echo "[-] Docker not found. Required for Open WebUI."
fi

# Check / Install pnpm
if command -v pnpm &>/dev/null; then
    echo "[✓] pnpm: $(pnpm --version)"
else
    echo "[!] pnpm not found. Installing via npm..."
    npm install -g pnpm 2>/dev/null || echo "[-] Failed to install pnpm"
fi

# Init submodules
echo ""
echo "[+] Initializing git submodules..."
git submodule update --init --recursive

# Pull recommended models
echo ""
echo "[+] Setup complete! Run the following to pull models:"
echo "    bash scripts/pull-models.sh"
echo ""
echo "[+] Quick start:"
echo "    docker compose -f docker/docker-compose.yml up -d    # Open WebUI"
echo "    cd frameworks/dulus && pip install -e . && dulus      # Dulus Agent"
echo "    cd frameworks/aider && pip install -e . && aider      # Aider coding"
