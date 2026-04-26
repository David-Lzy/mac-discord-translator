#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_FILE="$REPO_ROOT/config/config.smoke-test.json"

read -r -p "Discord Bot Token: " BOT_TOKEN
read -r -p "Discord Guild ID: " GUILD_ID
read -r -p "Translation endpoint base URL [http://127.0.0.1:8000/v1]: " VLLM_BASE_URL
VLLM_BASE_URL=${VLLM_BASE_URL:-http://127.0.0.1:8000/v1}
read -r -p "Translation model name [/model]: " VLLM_MODEL
VLLM_MODEL=${VLLM_MODEL:-/model}
read -r -p "Smoke-test mode: pair or group? [group]: " MODE
MODE=${MODE:-group}

if [[ "$MODE" == "pair" ]]; then
  read -r -p "English channel ID: " EN_ID
  read -r -p "Chinese channel ID: " ZH_ID
  PAIRS="$EN_ID:$ZH_ID"
  GROUPS=""
else
  read -r -p "Chinese channel ID: " ZH_ID
  read -r -p "English channel ID: " EN_ID
  read -r -p "Optional Japanese channel ID (blank to skip): " JA_ID
  GROUPS="smoketest>${ZH_ID}|zh,${EN_ID}|en"
  if [[ -n "$JA_ID" ]]; then
    GROUPS="$GROUPS,${JA_ID}|ja"
  fi
  PAIRS=""
fi

python3 - <<PY
import json, pathlib
cfg = {
  "discord": {
    "botToken": r"$BOT_TOKEN",
    "guildId": r"$GUILD_ID",
    "webhookMode": True,
    "mentionOriginalAuthor": False,
  },
  "translation": {
    "vllmBaseUrl": r"$VLLM_BASE_URL",
    "vllmModel": r"$VLLM_MODEL",
    "enableLocalMlxApi": False,
    "mlxHost": "127.0.0.1",
    "mlxPort": 5010,
    "mlxModel": "mlx-community/Qwen3.5-0.8B-4bit",
  },
  "mirrorBot": {
    "channelGroups": [item for item in r"$GROUPS".split(';') if item.strip()],
    "channelPairs": [item for item in r"$PAIRS".split(';') if item.strip()],
  },
}
path = pathlib.Path(r"$OUT_FILE")
path.write_text(json.dumps(cfg, indent=2, ensure_ascii=False) + "\n")
print(path)
PY

python3 "$REPO_ROOT/bin/validate-config.py" "$OUT_FILE"
echo "Generated smoke-test config: $OUT_FILE"
echo "Next: ./bin/preflight.sh --config $OUT_FILE --check-discord"
echo "      ./bin/deploy.sh --config $OUT_FILE --dry-run"
