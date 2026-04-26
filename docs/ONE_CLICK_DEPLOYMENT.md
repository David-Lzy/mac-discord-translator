# One-Click Deployment on macOS

This project now includes a simple deployment flow for macOS.

## Prerequisites

Before deployment, the user still needs to prepare a few things manually:

1. A Discord bot token
2. The bot already invited into the target server
3. Proper Discord permissions configured
4. Message Content Intent enabled in Discord Developer Portal
5. Channel IDs prepared for either:
   - pair mode
   - multilingual group mode
6. A translation backend configured
   - local MLX API
   - or remote OpenAI-compatible / vLLM-compatible endpoint

---

## Fast path

```bash
./bin/install.sh
./bin/setup-wizard.sh
./bin/deploy.sh --dry-run
./bin/deploy.sh
./bin/status.sh
```

---


## Validation and dry-run

Before installing LaunchAgents for real, use:

```bash
./bin/deploy.sh --dry-run
```

This will:

- validate `config/config.local.json`
- generate local env files
- stop before installing / restarting services

This is the safest way to catch:

- bad guild ids
- malformed channel group syntax
- empty bot token
- invalid translation URL


## What each script does

### `./bin/install.sh`

- checks basic macOS prerequisites
- installs mirror-bot npm dependencies
- creates Python venv for the MLX API
- installs core MLX-related Python packages
- creates `config/config.local.json` from the example if missing

### `./bin/setup-wizard.sh`

Interactive configuration helper.

It asks for:

- Discord bot token
- Discord guild ID
- translation endpoint base URL
- model name
- whether to enable local MLX LaunchAgent
- multilingual channel groups
- classic EN:ZH channel pairs

Then it writes:

- `config/config.local.json`

### `./bin/deploy.sh`

- reads `config/config.local.json`
- generates local env files under `config/generated/`
- creates LaunchAgents
- bootstraps / restarts the local services

Generated LaunchAgents:

- `ai.mac-discord-translator.mirror-bot`
- `ai.mac-discord-translator.mlx-api`

### `./bin/status.sh`

Shows:

- launchctl service status
- recent mirror-bot logs
- MLX API `/health` result when enabled

### `./bin/start.sh` / `./bin/stop.sh`

Convenience helpers for starting or stopping the local LaunchAgents.

---

## Config file example

See:

- `config/config.example.json`

Main local file:

- `config/config.local.json`

---

## Current scope of automation

This automation currently handles **local machine setup and service deployment**.

It does **not** automatically:

- create Discord channels
- set Discord role permissions in the server
- enable intents inside Discord Developer Portal
- register external model providers for you

Those still need to be prepared first.

Once those are ready, this project can take over the Mac-side deployment flow.

---

## Good next step for future improvement

If this project becomes more productized, the next layer would be:

- validating Discord permissions before deploy
- optional channel creation helpers
- optional OCR/image translation flow
- richer config validation and dry-run mode
