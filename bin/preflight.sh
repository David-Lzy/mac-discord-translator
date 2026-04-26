#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/config/config.local.json"
CHECK_DISCORD=false

usage() {
  cat <<EOF
Usage:
  ./bin/preflight.sh [--config PATH] [--check-discord]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --check-discord)
      CHECK_DISCORD=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "PREFLIGHT ERROR: missing required command: $1" >&2; exit 1; }
}

need_cmd node
need_cmd npm
need_cmd python3
need_cmd curl

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "PREFLIGHT ERROR: this project currently targets macOS." >&2
  exit 1
fi

python3 "$REPO_ROOT/bin/validate-config.py" "$CONFIG_FILE"

if [[ ! -d "$REPO_ROOT/discord-mirror-bot/node_modules" ]]; then
  echo "PREFLIGHT WARNING: discord-mirror-bot/node_modules missing. Run ./bin/install.sh"
fi
if [[ ! -d "$REPO_ROOT/mlx-qwen35-translate/.venv" ]]; then
  echo "PREFLIGHT WARNING: mlx-qwen35-translate/.venv missing. Run ./bin/install.sh"
fi

ENABLE_LOCAL_MLX=$(python3 - <<PY
import json, pathlib
cfg = json.loads(pathlib.Path(r"$CONFIG_FILE").read_text())
print('true' if cfg['translation'].get('enableLocalMlxApi', False) else 'false')
print(cfg['translation'].get('vllmBaseUrl', ''))
PY
)
MLX_ENABLED=$(echo "$ENABLE_LOCAL_MLX" | sed -n '1p')
VLLM_URL=$(echo "$ENABLE_LOCAL_MLX" | sed -n '2p')

if [[ "$MLX_ENABLED" == "true" && "$(uname -m)" != "arm64" ]]; then
  echo "PREFLIGHT WARNING: local MLX API is enabled but host arch is not arm64. MLX may not work as expected."
fi

if curl -fsS "$VLLM_URL/models" >/dev/null 2>&1; then
  echo "PREFLIGHT OK: translation endpoint reachable at $VLLM_URL"
else
  echo "PREFLIGHT WARNING: translation endpoint not reachable at $VLLM_URL/models right now"
fi

if [[ "$CHECK_DISCORD" == "true" ]]; then
  python3 "$REPO_ROOT/bin/check-discord-config.py" "$CONFIG_FILE"
else
  echo "PREFLIGHT NOTE: skip Discord API check (use --check-discord to verify bot access and channel IDs)"
fi

echo "PREFLIGHT OK"
