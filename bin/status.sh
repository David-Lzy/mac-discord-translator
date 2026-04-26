#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MIRROR_LABEL="ai.mac-discord-translator.mirror-bot"
MLX_LABEL="ai.mac-discord-translator.mlx-api"
CONFIG_FILE="$REPO_ROOT/config/config.local.json"

echo "== config validation =="
if [[ -f "$CONFIG_FILE" ]]; then
  python3 "$REPO_ROOT/bin/validate-config.py" "$CONFIG_FILE" || true
else
  echo "No config/config.local.json found"
fi

echo
echo "== discord API check =="
if [[ -f "$CONFIG_FILE" ]]; then
  python3 "$REPO_ROOT/bin/check-discord-config.py" "$CONFIG_FILE" || true
else
  echo "No config/config.local.json found"
fi

echo
echo "== launchctl statuses =="
launchctl print gui/$(id -u)/$MIRROR_LABEL 2>/dev/null | sed -n '1,25p' || echo "mirror bot not loaded (tip: run ./bin/deploy.sh)"
launchctl print gui/$(id -u)/$MLX_LABEL 2>/dev/null | sed -n '1,25p' || echo "mlx api not loaded (this is OK if enableLocalMlxApi=false)"

echo
echo "== mirror bot logs =="
tail -n 20 "$REPO_ROOT/discord-mirror-bot/mirror-bot.log" 2>/dev/null || echo "No mirror-bot.log yet"

echo
echo "== generated env files =="
ls -1 "$REPO_ROOT/config/generated" 2>/dev/null || echo "No generated env files yet (tip: run ./bin/deploy.sh --dry-run first)"

echo
echo "== mlx api health =="
if curl -fsS http://127.0.0.1:5010/health 2>/dev/null; then
  echo
else
  echo "mlx api health check failed or disabled"
fi
