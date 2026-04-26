#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/config/config.local.json"
mkdir -p "$REPO_ROOT/config"

read -r -p "Discord Bot Token: " BOT_TOKEN
read -r -p "Discord Guild ID: " GUILD_ID
read -r -p "Translation endpoint base URL (e.g. http://127.0.0.1:8000/v1): " VLLM_BASE_URL
read -r -p "Translation model name [/model]: " VLLM_MODEL
VLLM_MODEL=${VLLM_MODEL:-/model}
read -r -p "Enable local MLX API LaunchAgent? [y/N]: " ENABLE_LOCAL
read -r -p "Mirror channel groups (semicolon separated, optional): " CHANNEL_GROUPS
read -r -p "Mirror channel pairs EN:ZH (semicolon separated, optional): " CHANNEL_PAIRS

ENABLE_BOOL=false
if [[ "$ENABLE_LOCAL" =~ ^[Yy]$ ]]; then
  ENABLE_BOOL=true
fi

python3 - <<PY
import json, pathlib
repo_root = pathlib.Path(r"$REPO_ROOT")
config_file = pathlib.Path(r"$CONFIG_FILE")
config = {
  "discord": {
    "botToken": r"$BOT_TOKEN",
    "guildId": r"$GUILD_ID",
    "webhookMode": True,
    "mentionOriginalAuthor": False,
  },
  "translation": {
    "vllmBaseUrl": r"$VLLM_BASE_URL",
    "vllmModel": r"$VLLM_MODEL",
    "enableLocalMlxApi": $ENABLE_BOOL,
    "mlxHost": "127.0.0.1",
    "mlxPort": 5010,
    "mlxModel": "mlx-community/Qwen3.5-0.8B-4bit",
  },
  "mirrorBot": {
    "channelGroups": [item for item in r"$CHANNEL_GROUPS".split(';') if item.strip()],
    "channelPairs": [item for item in r"$CHANNEL_PAIRS".split(';') if item.strip()],
  },
}
config_file.write_text(json.dumps(config, indent=2, ensure_ascii=False) + "\n")
print(f"Wrote {config_file}")
PY

echo "Now run: ./bin/deploy.sh"
