#!/usr/bin/env bash
set -euo pipefail

# One-time setup for LAM avatar generation + OpenAvatarChat integration.
# Usage:
#   bash scripts/setup_lam_asset_pipeline.sh [--blender /path/to/blender]

BLENDER_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --blender)
      BLENDER_PATH="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown arg: $1"
      exit 1
      ;;
  esac
done

ROOT="/home/nbrown"
LAM_DIR="$ROOT/LAM"
OAC_DIR="$ROOT/OpenAvatarChat"
CONDA="$ROOT/miniconda3/bin/conda"
ENV_NAME="lam_py310"

if [[ ! -x "$CONDA" ]]; then
  echo "Conda not found at $CONDA"
  exit 1
fi

if [[ ! -d "$LAM_DIR" ]]; then
  echo "Cloning LAM repo..."
  git clone https://github.com/aigc3d/LAM.git "$LAM_DIR"
fi

echo "Ensuring conda env '$ENV_NAME' exists..."
if ! "$CONDA" env list | awk '{print $1}' | grep -qx "$ENV_NAME"; then
  "$CONDA" create -y -n "$ENV_NAME" python=3.10
fi

echo "Installing LAM dependencies (CUDA 12.1 profile)..."
"$CONDA" run -n "$ENV_NAME" bash -lc "cd '$LAM_DIR' && bash scripts/install/install_cu121.sh"

echo "Installing export dependencies..."
"$CONDA" run -n "$ENV_NAME" pip install pathlib patool

FBX_WHL="$LAM_DIR/fbx-2020.3.4-cp310-cp310-manylinux1_x86_64.whl"
if [[ ! -f "$FBX_WHL" ]]; then
  echo "Downloading FBX wheel..."
  wget -q https://virutalbuy-public.oss-cn-hangzhou.aliyuncs.com/share/aigc3d/data/LAM/fbx-2020.3.4-cp310-cp310-manylinux1_x86_64.whl -O "$FBX_WHL"
fi
"$CONDA" run -n "$ENV_NAME" pip install "$FBX_WHL"

SAMPLE_TAR="$LAM_DIR/sample_oac.tar"
if [[ ! -f "$SAMPLE_TAR" ]]; then
  echo "Downloading OpenAvatarChat export template..."
  wget -q https://virutalbuy-public.oss-cn-hangzhou.aliyuncs.com/share/aigc3d/data/LAM/sample_oac.tar -O "$SAMPLE_TAR"
fi
mkdir -p "$LAM_DIR/assets"
tar -xf "$SAMPLE_TAR" -C "$LAM_DIR/assets"

echo ""
echo "Setup complete. Next steps:"
echo "1) Start LAM UI and generate avatar from your image:"
if [[ -n "$BLENDER_PATH" ]]; then
  echo "   $CONDA run -n $ENV_NAME bash -lc 'cd $LAM_DIR && python app_lam.py --blender_path $BLENDER_PATH'"
else
  echo "   $CONDA run -n $ENV_NAME bash -lc 'cd $LAM_DIR && python app_lam.py --blender_path /path/to/blender'"
fi
echo "2) In LAM UI, use Export Chatting Avatar to create a .zip"
echo "3) Copy exported zip into OpenAvatarChat lam_samples, e.g.:"
echo "   cp /path/to/your_avatar.zip $OAC_DIR/src/handlers/client/ws_lam_client/lam_samples/"
echo "4) Update OpenAvatarChat config asset_path to that zip name."
