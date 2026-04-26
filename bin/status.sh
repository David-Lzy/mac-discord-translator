#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "== launchctl statuses =="
launchctl print gui/$(id -u)/ai.mac-discord-translator.mirror-bot 2>/dev/null | sed -n '1,25p' || echo "mirror bot not loaded"
launchctl print gui/$(id -u)/ai.mac-discord-translator.mlx-api 2>/dev/null | sed -n '1,25p' || echo "mlx api not loaded"
echo
echo "== mirror bot logs =="
tail -n 20 "$REPO_ROOT/discord-mirror-bot/mirror-bot.log" 2>/dev/null || true
echo
echo "== mlx api health =="
curl -fsS http://127.0.0.1:5010/health 2>/dev/null || echo "mlx api health check failed or disabled"
