# Development Status - 2026-04-27

## Current development progress

### Product / repo state
- Public repo has been generalized from a Foundation-specific export into a reusable macOS project:
  - Repo: `https://github.com/David-Lzy/mac-discord-translator`
- Repo now contains:
  - local MLX translation API wrapper
  - Discord mirror bot
  - setup / migration / deployment docs
  - one-click-ish deployment scripts for macOS

### Mirror bot capabilities completed
- Standard EN↔ZH pair mode
- Multilingual group mode
- Attachment / image forwarding
- Off-topic multilingual translation group verified in Discord with:
  - `zh`
  - `en`
  - `ja`
  - `fr`
  - `de`
  - `es`
  - `ru`
- Private channel pair translation also verified

### Productization work completed
- Repo renamed to `mac-discord-translator`
- README rewritten for public/open use
- Added deployment tooling:
  - `bin/install.sh`
  - `bin/setup-wizard.sh`
  - `bin/deploy.sh`
  - `bin/start.sh`
  - `bin/stop.sh`
  - `bin/status.sh`
- Added validation and safer rollout tooling:
  - `bin/validate-config.py`
  - `bin/preflight.sh`
  - `bin/check-discord-config.py`
  - `bin/generate-smoke-test-config.sh`
- Added docs:
  - `docs/ONE_CLICK_DEPLOYMENT.md`
  - `docs/DISCORD_PERMISSIONS_CHECKLIST.md`

### Validation already done
- Shell syntax checks passed on deployment scripts
- `node --check` passed for mirror bot
- `python -m py_compile` passed for local MLX API and helper scripts
- `deploy.sh --dry-run` passed with a realistic test config
- `preflight.sh` passed with a realistic test config

---

## Current service / auto-start status on this Mac

### 1. OpenClaw gateway
- LaunchAgent exists: `~/Library/LaunchAgents/ai.openclaw.gateway.plist`
- `launchctl` shows it loaded and running
- Conclusion: **will auto-start after login/restart**

### 2. Local MLX translation API
- LaunchAgent exists: `~/Library/LaunchAgents/ai.openclaw.mlx-translate-api.plist`
- Config points to:
  - script: `scripts/mlx-qwen35-translate/run-server.sh`
  - local port: `127.0.0.1:5010`
- Health check currently works:
  - `http://127.0.0.1:5010/health`
- Conclusion: **already configured to auto-start after login/restart**

### 3. Current Discord mirror bot instance
- `mac-discord-translator` has now been deployed locally with a real `config/config.local.json`
- LaunchAgent exists and is loaded:
  - `~/Library/LaunchAgents/ai.mac-discord-translator.mirror-bot.plist`
- `./bin/status.sh` now verifies:
  - config validation OK
  - Discord API access OK for all configured channels
  - LaunchAgent state = running
  - bot login log present in `discord-mirror-bot/mirror-bot.log`
- Old ad-hoc process path (`node scripts/discord-mirror-bot/index.js`) has been retired
- Conclusion: **current mirror bot is now configured to auto-start after macOS login/reboot via LaunchAgent**

### 4. Remote OpenAI-compatible translation endpoint for mirror bot
- Current old mirror bot uses a remote endpoint rather than the local MLX API for message translation
- Its availability is separate from macOS login auto-start on this machine
- Even if the mirror bot auto-starts locally, translation still depends on that remote endpoint being reachable

---

## What needs to be done to make the mirror bot auto-start properly

### Recommended path
Use the new repo as the canonical deployment path.

From:
- `/Users/davidli/.openclaw/workspace/mac-discord-translator`

Do:

```bash
./bin/install.sh
./bin/setup-wizard.sh
./bin/preflight.sh --check-discord
./bin/deploy.sh --dry-run
./bin/deploy.sh
./bin/status.sh
```

That will:
- write `config/config.local.json`
- generate env files in `config/generated/`
- install LaunchAgent:
  - `~/Library/LaunchAgents/ai.mac-discord-translator.mirror-bot.plist`
- optionally install local MLX LaunchAgent too
- make the mirror bot restart automatically after login/reboot

### Important caveat
These are **LaunchAgents**, not system daemons.
So the behavior is:
- they auto-start **after the macOS user logs in**
- they do **not** start before user login at the macOS login screen

That is normal and acceptable for this project’s current shape.

---

## Practical current conclusion

### Already auto-starting
- OpenClaw gateway
- local MLX translation API

### Already auto-starting in the new generalized deployment flow
- `mac-discord-translator` mirror bot

### Why
Because the new public repo has now been **deployed locally with a real `config/config.local.json`**, generated env files, and a loaded LaunchAgent.

---

## Next recommended actions

### If we want to stop here cleanly
- Keep this file as the handoff / checkpoint note

### If we want to continue next
1. Keep `config/config.local.json` as the canonical local deployment config
2. Use `./bin/preflight.sh --check-discord` before future config changes
3. Use `./bin/deploy.sh` after config updates to refresh generated env + LaunchAgent wiring
4. Optionally switch mirror bot to a local translation backend instead of the current remote one
5. Optionally add a small smoke test that posts into lab channels and verifies relay end-to-end

---

## Good next build items after deployment
- Better terminal UI / colored installer output
- More guided config generation for pair/group setups
- Optional channel creation helper
- Optional OCR / image text translation
- Better local-vs-remote backend selection UX
