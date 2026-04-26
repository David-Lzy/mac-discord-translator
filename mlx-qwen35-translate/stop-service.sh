#!/usr/bin/env bash
set -euo pipefail
LABEL="ai.openclaw.mlx-translate-api"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
launchctl bootout gui/$(id -u) "$PLIST"
