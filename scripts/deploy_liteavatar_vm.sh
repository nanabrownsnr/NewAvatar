#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIG_PATH="${1:-config/chat_with_openai_compatible_bailian_cosyvoice.yaml}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

echo "[1/8] Preflight: repo + gpu"
test -f "$CONFIG_PATH"
command -v git >/dev/null
if command -v nvidia-smi >/dev/null; then
  if ! nvidia-smi >/dev/null 2>&1; then
    echo "WARNING: nvidia-smi is present but returned non-zero."
    echo "Continuing; verify GPU visibility before production use."
  fi
else
  echo "WARNING: nvidia-smi not found in PATH."
fi

echo "[2/8] Ensure git-lfs and submodules"
if ! command -v git-lfs >/dev/null; then
  echo "ERROR: git-lfs is required but not installed."
  echo "Install it first: sudo apt-get update && sudo apt-get install -y git-lfs"
  exit 1
fi
git lfs install
git submodule sync --recursive
git submodule update --init --recursive --depth 1

echo "[3/8] Ensure uv is installed"
if ! command -v uv >/dev/null; then
  if ! "$PYTHON_BIN" -m pip --version >/dev/null 2>&1; then
    if [[ -x "$HOME/miniconda3/bin/python" ]] && "$HOME/miniconda3/bin/python" -m pip --version >/dev/null 2>&1; then
      PYTHON_BIN="$HOME/miniconda3/bin/python"
    elif "$PYTHON_BIN" -m ensurepip --upgrade >/dev/null 2>&1; then
      :
    else
      echo "ERROR: no working pip found for $PYTHON_BIN."
      echo "Set PYTHON_BIN to a python with pip, e.g. PYTHON_BIN=$HOME/miniconda3/bin/python"
      exit 1
    fi
  fi
  "$PYTHON_BIN" -m pip install --user uv
  export PATH="$HOME/.local/bin:$PATH"
fi
command -v uv >/dev/null

echo "[4/8] Ensure .env exists"
if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example"
  echo "Set DASHSCOPE_API_KEY in .env before runtime."
fi

echo "[5/8] Ensure TLS certs exist"
mkdir -p ssl_certs
if [[ ! -f ssl_certs/localhost.crt || ! -f ssl_certs/localhost.key ]]; then
  openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout ssl_certs/localhost.key \
    -out ssl_certs/localhost.crt \
    -days 3650 \
    -subj "/C=US/ST=NA/L=NA/O=OpenAvatarChat/OU=Dev/CN=localhost"
fi

echo "[6/8] Install python dependencies"
uv run install.py --config "$CONFIG_PATH"

echo "[7/8] Download required models"
uv run scripts/download_models.py --config "$CONFIG_PATH" --source huggingface

echo "[8/8] Launch service"
echo "Open https://<vm-ip>:8282/ui/index.html"
exec uv run src/demo.py --config "$CONFIG_PATH"
