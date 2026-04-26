#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/config/config.local.json"
mkdir -p "$REPO_ROOT/config"

prompt_required() {
  local label="$1"
  local value=""
  while [[ -z "$value" ]]; do
    read -r -p "$label" value
    if [[ -z "$value" ]]; then
      echo "This value is required."
    fi
  done
  printf '%s' "$value"
}

echo "mac-discord-translator setup wizard"
echo "Press Enter to accept defaults where shown."
echo

BOT_TOKEN=$(prompt_required "Discord Bot Token: ")
GUILD_ID=$(prompt_required "Discord Guild ID: ")
VLLM_BASE_URL=$(prompt_required "Translation endpoint base URL (e.g. http://127.0.0.1:8000/v1): ")
read -r -p "Translation model name [/model]: " VLLM_MODEL
VLLM_MODEL=${VLLM_MODEL:-/model}
read -r -p "Enable local MLX API LaunchAgent? [y/N]: " ENABLE_LOCAL
read -r -p "Enable webhook mode? [Y/n]: " WEBHOOK_MODE_RAW
read -r -p "Mention original author in relayed messages? [y/N]: " MENTION_AUTHOR_RAW
read -r -p "Mirror channel groups (semicolon separated, optional): " CHANNEL_GROUPS
read -r -p "Mirror channel pairs EN:ZH (semicolon separated, optional): " CHANNEL_PAIRS

ENABLE_BOOL=false
[[ "$ENABLE_LOCAL" =~ ^[Yy]$ ]] && ENABLE_BOOL=true
WEBHOOK_BOOL=true
[[ "$WEBHOOK_MODE_RAW" =~ ^[Nn]$ ]] && WEBHOOK_BOOL=false
MENTION_BOOL=false
[[ "$MENTION_AUTHOR_RAW" =~ ^[Yy]$ ]] && MENTION_BOOL=true

python3 - <<PY
import json, pathlib
config_file = pathlib.Path(r"$CONFIG_FILE")
config = {
  "discord": {
    "botToken": r"$BOT_TOKEN",
    "guildId": r"$GUILD_ID",
    "webhookMode": $WEBHOOK_BOOL,
    "mentionOriginalAuthor": $MENTION_BOOL,
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

python3 "$REPO_ROOT/bin/validate-config.py" "$CONFIG_FILE"

echo
echo "Config validated. Next steps:"
echo "  ./bin/deploy.sh --dry-run"
echo "  ./bin/deploy.sh"
