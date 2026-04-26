#!/usr/bin/env bash
set -euo pipefail
launchctl bootstrap gui/$(id -u) "$HOME/Library/LaunchAgents/ai.mac-discord-translator.mirror-bot.plist" 2>/dev/null || true
launchctl kickstart -k gui/$(id -u)/ai.mac-discord-translator.mirror-bot 2>/dev/null || true
if [[ -f "$HOME/Library/LaunchAgents/ai.mac-discord-translator.mlx-api.plist" ]]; then
  launchctl bootstrap gui/$(id -u) "$HOME/Library/LaunchAgents/ai.mac-discord-translator.mlx-api.plist" 2>/dev/null || true
  launchctl kickstart -k gui/$(id -u)/ai.mac-discord-translator.mlx-api 2>/dev/null || true
fi
echo "Started mac-discord-translator services."
