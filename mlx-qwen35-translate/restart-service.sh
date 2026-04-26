#!/usr/bin/env bash
set -euo pipefail
LABEL="ai.openclaw.mlx-translate-api"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
launchctl bootout gui/$(id -u) "$PLIST" >/dev/null 2>&1 || true
launchctl bootstrap gui/$(id -u) "$PLIST"
launchctl kickstart -k gui/$(id -u)/$LABEL
launchctl print gui/$(id -u)/$LABEL | sed -n '1,60p'
