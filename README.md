# Foundation Discord Translation Stack

A cleaned-up export of the local Discord translation workflow used for the Foundation server.

This repository intentionally includes only:

- custom local translation API wrapper code
- custom Discord mirror bot code
- setup / migration / operations documentation
- notes on how to integrate the upstream reaction-translation bot

This repository intentionally excludes:

- secrets (`.env`, tokens, SSH keys)
- runtime logs
- `node_modules` / `.venv`
- downloaded models
- upstream third-party source trees

## Included components

### 1. `mlx-qwen35-translate/`
Local MLX-based translation API exposing a LibreTranslate-compatible `/translate` endpoint.

### 2. `discord-mirror-bot/`
Custom Discord mirror bot supporting:

- EN↔ZH channel pairs
- multilingual channel groups
- image / attachment forwarding
- webhook-based sender mirroring

### 3. `docs/`
Consolidated setup, migration, permissions, and deployment notes.

## Not included, but documented

The reaction-based Discord bot is based on an upstream .NET project and is documented here, but its source code is not included in this export.
See `upstreams/README.md`.

## Suggested use

1. Bring up the local translation API or your own OpenAI-compatible translation endpoint.
2. Configure the mirror bot with `.env`.
3. Create Discord bot permissions and channel mappings.
4. Start the bot and test with a real user account.
