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

TRANSLATION_INFO=$(python3 - <<PY
import json, pathlib
cfg = json.loads(pathlib.Path(r"$CONFIG_FILE").read_text())
print('true' if cfg['translation'].get('enableLocalMlxApi', False) else 'false')
print(cfg['translation'].get('vllmBaseUrl', ''))
print(cfg['translation'].get('vllmModel', ''))
PY
)
MLX_ENABLED=$(echo "$TRANSLATION_INFO" | sed -n '1p')
VLLM_URL=$(echo "$TRANSLATION_INFO" | sed -n '2p')
VLLM_MODEL=$(echo "$TRANSLATION_INFO" | sed -n '3p')

if [[ "$MLX_ENABLED" == "true" && "$(uname -m)" != "arm64" ]]; then
  echo "PREFLIGHT WARNING: local MLX API is enabled but host arch is not arm64. MLX may not work as expected."
fi

MODEL_CHECK=$(python3 - <<PY
import json, sys, urllib.request
base = "$VLLM_URL".rstrip('/')
model = "$VLLM_MODEL".strip()
url = f"{base}/models"
try:
    with urllib.request.urlopen(url, timeout=15) as resp:
        payload = json.loads(resp.read().decode('utf-8'))
except Exception as exc:
    print(f"PREFLIGHT WARNING: translation endpoint not reachable at {url} ({exc})")
    sys.exit(0)

models = payload.get('data', []) if isinstance(payload, dict) else []
ids = [str(item.get('id', '')).strip() for item in models if isinstance(item, dict)]
roots = [str(item.get('root', '')).strip() for item in models if isinstance(item, dict)]
print(f"PREFLIGHT OK: translation endpoint reachable at {base}")
if model in ids:
    print(f"PREFLIGHT OK: configured model '{model}' is exposed by /models")
elif model in roots:
    matches = [ids[i] for i, root in enumerate(roots) if root == model and i < len(ids) and ids[i]]
    suggestion = matches[0] if matches else '(no id suggestion available)'
    print(f"PREFLIGHT WARNING: configured model '{model}' matches a model root, not an exposed id. Try model id: {suggestion}")
else:
    preview = ', '.join(ids[:5]) if ids else '(no models returned)'
    print(f"PREFLIGHT WARNING: configured model '{model}' not found in /models ids. Available ids: {preview}")
PY
)
echo "$MODEL_CHECK"

if [[ "$CHECK_DISCORD" == "true" ]]; then
  python3 "$REPO_ROOT/bin/check-discord-config.py" "$CONFIG_FILE"
else
  echo "PREFLIGHT NOTE: skip Discord API check (use --check-discord to verify bot access and channel IDs)"
fi

echo "PREFLIGHT OK"
