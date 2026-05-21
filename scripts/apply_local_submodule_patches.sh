#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH_DIR="$ROOT_DIR/patches/submodules"

apply_patch() {
  local repo_dir="$1"
  local patch_file="$2"
  local name="$3"

  if git -C "$repo_dir" apply --check "$patch_file"; then
    git -C "$repo_dir" apply "$patch_file"
    echo "[applied] $name"
    return
  fi

  if git -C "$repo_dir" apply --reverse --check "$patch_file"; then
    echo "[skip] $name already applied"
    return
  fi

  echo "[error] Cannot apply $name cleanly. Check submodule version and local edits." >&2
  exit 1
}

cd "$ROOT_DIR"
git submodule update --init --recursive

apply_patch \
  "$ROOT_DIR/src/service/frontend_service/frontend" \
  "$PATCH_DIR/openavatarchat-webui.patch" \
  "frontend WebUI patch"

apply_patch \
  "$ROOT_DIR/src/handlers/avatar/lam/LAM_Audio2Expression" \
  "$PATCH_DIR/lam-audio2expression.patch" \
  "LAM Audio2Expression patch"

echo "Submodule patches are in place."
echo "Next: rebuild frontend artifacts if needed (cd src/service/frontend_service/frontend && npm ci && npm run build)."
