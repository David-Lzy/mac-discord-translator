#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO_ROOT/config/generated/mirror-bot.env"
LOG_FILE="$REPO_ROOT/discord-mirror-bot/mirror-bot.log"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE. Run ./bin/deploy.sh first." >&2
  exit 1
fi
set -a
source "$ENV_FILE"
set +a
cd "$REPO_ROOT/discord-mirror-bot"
exec node index.js >> "$LOG_FILE" 2>&1
