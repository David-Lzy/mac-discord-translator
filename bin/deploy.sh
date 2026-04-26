#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/config/config.local.json"
DRY_RUN=false
CHECK_DISCORD=true

usage() {
  cat <<USAGE
Usage:
  ./bin/deploy.sh [--config PATH] [--dry-run] [--skip-discord-check]

Options:
  --config PATH          Use a custom config file
  --dry-run              Validate and generate preview only; do not install LaunchAgents
  --skip-discord-check   Skip live Discord API channel access validation
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --skip-discord-check)
      CHECK_DISCORD=false
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

GENERATED_DIR="$REPO_ROOT/config/generated"
mkdir -p "$GENERATED_DIR"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Missing config file: $CONFIG_FILE" >&2
  echo "Copy config/config.example.json to config/config.local.json or run ./bin/setup-wizard.sh" >&2
  exit 1
fi

PREFLIGHT_ARGS=(--config "$CONFIG_FILE")
if [[ "$CHECK_DISCORD" == "true" ]]; then
  PREFLIGHT_ARGS+=(--check-discord)
fi
"$REPO_ROOT/bin/preflight.sh" "${PREFLIGHT_ARGS[@]}"

python3 - <<PY
import json, pathlib, shlex
config = json.loads(pathlib.Path(r"$CONFIG_FILE").read_text())
out_dir = pathlib.Path(r"$GENERATED_DIR")
out_dir.mkdir(parents=True, exist_ok=True)

discord = config["discord"]
translation = config["translation"]
mirror = config["mirrorBot"]

def line(key, value):
    return f"{key}={shlex.quote(str(value))}\n"

mirror_env = "".join([
    line('DISCORD_BOT_TOKEN', discord['botToken']),
    line('DISCORD_GUILD_ID', discord['guildId']),
    line('MIRROR_CHANNEL_GROUPS', ';'.join(mirror.get('channelGroups', []))),
    line('MIRROR_CHANNEL_PAIRS', ';'.join(mirror.get('channelPairs', []))),
    line('VLLM_BASE_URL', translation['vllmBaseUrl']),
    line('VLLM_MODEL', translation['vllmModel']),
    line('WEBHOOK_MODE', 'true' if discord.get('webhookMode', True) else 'off'),
    line('MENTION_ORIGINAL_AUTHOR', 'true' if discord.get('mentionOriginalAuthor', False) else 'false'),
])
(out_dir / 'mirror-bot.env').write_text(mirror_env)

mlx_env = "".join([
    line('MLX_TRANSLATE_HOST', translation.get('mlxHost', '127.0.0.1')),
    line('MLX_TRANSLATE_PORT', translation.get('mlxPort', 5010)),
    line('MLX_TRANSLATE_MODEL', translation.get('mlxModel', 'mlx-community/Qwen3.5-0.8B-4bit')),
    line('MLX_TRANSLATE_MAX_TOKENS', 512),
])
(out_dir / 'mlx-api.env').write_text(mlx_env)
PY

ENABLE_LOCAL_MLX=$(python3 - <<PY
import json, pathlib
cfg = json.loads(pathlib.Path(r"$CONFIG_FILE").read_text())
print('true' if cfg['translation'].get('enableLocalMlxApi', False) else 'false')
PY
)

echo "Prepared generated env files in: $GENERATED_DIR"
echo "  - mirror-bot.env"
echo "  - mlx-api.env"
echo "Local MLX LaunchAgent enabled: $ENABLE_LOCAL_MLX"

if [[ "$DRY_RUN" == "true" ]]; then
  echo
  echo "Dry run only: validation passed, env files generated, LaunchAgents were not installed."
  exit 0
fi

if ! command -v launchctl >/dev/null 2>&1; then
  echo "launchctl not found. This deploy script currently targets macOS." >&2
  exit 1
fi

cat > "$HOME/Library/LaunchAgents/ai.mac-discord-translator.mirror-bot.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>ai.mac-discord-translator.mirror-bot</string>
  <key>ProgramArguments</key>
  <array>
    <string>$REPO_ROOT/bin/run-mirror-bot.sh</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>WorkingDirectory</key><string>$REPO_ROOT</string>
  <key>StandardOutPath</key><string>$REPO_ROOT/discord-mirror-bot/mirror-bot.launchd.out.log</string>
  <key>StandardErrorPath</key><string>$REPO_ROOT/discord-mirror-bot/mirror-bot.launchd.err.log</string>
</dict>
</plist>
PLIST

if [[ "$ENABLE_LOCAL_MLX" == "true" ]]; then
cat > "$HOME/Library/LaunchAgents/ai.mac-discord-translator.mlx-api.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>ai.mac-discord-translator.mlx-api</string>
  <key>ProgramArguments</key>
  <array>
    <string>$REPO_ROOT/bin/run-mlx-api.sh</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>WorkingDirectory</key><string>$REPO_ROOT</string>
  <key>StandardOutPath</key><string>$REPO_ROOT/mlx-qwen35-translate/mlx-api.launchd.out.log</string>
  <key>StandardErrorPath</key><string>$REPO_ROOT/mlx-qwen35-translate/mlx-api.launchd.err.log</string>
</dict>
</plist>
PLIST
fi

launchctl bootout gui/$(id -u) "$HOME/Library/LaunchAgents/ai.mac-discord-translator.mirror-bot.plist" >/dev/null 2>&1 || true
launchctl bootstrap gui/$(id -u) "$HOME/Library/LaunchAgents/ai.mac-discord-translator.mirror-bot.plist"
launchctl kickstart -k gui/$(id -u)/ai.mac-discord-translator.mirror-bot

if [[ "$ENABLE_LOCAL_MLX" == "true" ]]; then
  launchctl bootout gui/$(id -u) "$HOME/Library/LaunchAgents/ai.mac-discord-translator.mlx-api.plist" >/dev/null 2>&1 || true
  launchctl bootstrap gui/$(id -u) "$HOME/Library/LaunchAgents/ai.mac-discord-translator.mlx-api.plist"
  launchctl kickstart -k gui/$(id -u)/ai.mac-discord-translator.mlx-api
fi

echo "Deployment complete."
echo "Run ./bin/status.sh to verify services."
