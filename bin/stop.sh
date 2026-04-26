#!/usr/bin/env bash
set -euo pipefail
launchctl bootout gui/$(id -u) "$HOME/Library/LaunchAgents/ai.mac-discord-translator.mirror-bot.plist" >/dev/null 2>&1 || true
launchctl bootout gui/$(id -u) "$HOME/Library/LaunchAgents/ai.mac-discord-translator.mlx-api.plist" >/dev/null 2>&1 || true
echo "Stopped mac-discord-translator services."
