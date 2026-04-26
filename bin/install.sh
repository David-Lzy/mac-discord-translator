#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "INSTALL ERROR: missing required command: $1" >&2; exit 1; }
}

need_cmd node
need_cmd npm
need_cmd python3
need_cmd curl

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "INSTALL ERROR: this installer currently targets macOS." >&2
  exit 1
fi

echo "[preflight]"
if [[ -f "$REPO_ROOT/config/config.local.json" ]]; then
  "$REPO_ROOT/bin/preflight.sh" --config "$REPO_ROOT/config/config.local.json" || true
else
  echo "No config/config.local.json yet; continuing with dependency install only."
fi

echo "[1/4] Installing mirror bot npm dependencies..."
cd "$REPO_ROOT/discord-mirror-bot"
npm install

cd "$REPO_ROOT"
echo "[2/4] Preparing Python virtual environment..."
python3 -m venv "$REPO_ROOT/mlx-qwen35-translate/.venv"
source "$REPO_ROOT/mlx-qwen35-translate/.venv/bin/activate"
pip install --upgrade pip
pip install mlx mlx-lm mlx-metal transformers sentencepiece huggingface_hub

echo "[3/4] Creating local config if missing..."
mkdir -p "$REPO_ROOT/config/generated"
if [[ ! -f "$REPO_ROOT/config/config.local.json" ]]; then
  cp "$REPO_ROOT/config/config.example.json" "$REPO_ROOT/config/config.local.json"
  echo "Created config/config.local.json from example."
fi

echo "[4/4] Install complete. Suggested next steps:"
echo "  1. ./bin/setup-wizard.sh    (or edit config/config.local.json manually)"
echo "  2. ./bin/deploy.sh --dry-run"
echo "  3. ./bin/deploy.sh"
echo "  4. ./bin/status.sh"
