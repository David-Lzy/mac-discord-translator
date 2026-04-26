# mac-discord-translator

Deployable **macOS Discord translation stack** for local or self-hosted use.

It is designed for people who want this workflow:

- prepare a Discord bot token and permissions
- point the project at a translation backend
- configure channel pairs or multilingual channel groups
- run **one setup flow**
- get a working translation relay on a Mac

This repository packages a practical stack that has already been used in a real Discord server.

---

## What it includes

### 1. Local MLX translation API
`mlx-qwen35-translate/`

A lightweight wrapper that runs an MLX model locally on Apple Silicon and exposes a **LibreTranslate-compatible** API:

- `GET /health`
- `GET /languages`
- `POST /translate`

This is useful when you want a local translation endpoint for bots or automations.

### 2. Discord mirror bot
`discord-mirror-bot/`

A custom Discord bot that listens to human messages and republishes translated versions into linked channels.

Supported features:

- **channel pairs**
  - e.g. English ↔ Chinese
- **multilingual groups**
  - e.g. `zh / en / ja / fr / de / es / ru`
- **attachment forwarding**
  - images / attachments are mirrored too
- **webhook sender mirroring**
  - translated messages can preserve the original sender name/avatar style

### 3. One-click-ish Mac deployment flow
`bin/`

This repo now includes:

- `install.sh`
- `setup-wizard.sh`
- `deploy.sh`
- `start.sh`
- `stop.sh`
- `status.sh`

The goal is simple:

1. install dependencies
2. fill in one config
3. deploy LaunchAgents
4. run as a persistent local service

### 4. Docs
`docs/`

Includes setup / migration / integration notes for:

- the local MLX API
- the mirror bot
- a reaction-based Discord translation bot integration
- the overall stack

---

## Repository layout

```text
mac-discord-translator/
├── README.md
├── .gitignore
├── bin/
│   ├── install.sh
│   ├── setup-wizard.sh
│   ├── deploy.sh
│   ├── start.sh
│   ├── stop.sh
│   ├── status.sh
│   ├── run-mirror-bot.sh
│   └── run-mlx-api.sh
├── config/
│   ├── config.example.json
│   └── generated/
├── docs/
│   ├── DISCORD_TRANSLATION_STACK_GUIDE.md
│   ├── MLX_SETUP_AND_MIGRATION.md
│   ├── MIRROR_BOT_SETUP_AND_MIGRATION.md
│   └── REACTION_BOT_SETUP_AND_MIGRATION.md
├── mlx-qwen35-translate/
├── discord-mirror-bot/
└── upstreams/
```

---

## Quick start

### Option A — guided path

```bash
./bin/install.sh
./bin/setup-wizard.sh
./bin/deploy.sh --dry-run
./bin/deploy.sh
./bin/status.sh
```

### Option B — manual config path

```bash
cp config/config.example.json config/config.local.json
# edit config/config.local.json
./bin/install.sh
./bin/deploy.sh
./bin/status.sh
```

---

## Configuration model

Main local config file:

- `config/config.local.json`

Example fields:

```json
{
  "discord": {
    "botToken": "PUT_DISCORD_BOT_TOKEN_HERE",
    "guildId": "PUT_DISCORD_GUILD_ID_HERE",
    "webhookMode": true,
    "mentionOriginalAuthor": false
  },
  "translation": {
    "vllmBaseUrl": "http://127.0.0.1:8000/v1",
    "vllmModel": "/model",
    "enableLocalMlxApi": true,
    "mlxHost": "127.0.0.1",
    "mlxPort": 5010,
    "mlxModel": "mlx-community/Qwen3.5-0.8B-4bit"
  },
  "mirrorBot": {
    "channelGroups": [
      "offtopic>CHANNEL_ID|zh,CHANNEL_ID|en,CHANNEL_ID|ja"
    ],
    "channelPairs": [
      "EN_CHANNEL_ID:ZH_CHANNEL_ID"
    ]
  }
}
```

---

## Safer deployment flow

This repository now includes:

- **config validation** via `bin/validate-config.py`
- **dry-run deployment** via `./bin/deploy.sh --dry-run`
- clearer `status.sh` output for common setup mistakes
- a Discord-side checklist at `docs/DISCORD_PERMISSIONS_CHECKLIST.md`

Recommended habit:

```bash
./bin/deploy.sh --dry-run
./bin/deploy.sh
```

Run the dry-run first whenever you change token, guild id, channel ids, or group layout.


## Pair mode vs group mode

### Pair mode

```json
"channelPairs": [
  "EN_CHANNEL_ID:ZH_CHANNEL_ID"
]
```

Good for classic bilingual mirrors.

### Group mode

```json
"channelGroups": [
  "offtopic>ZH_ID|zh,EN_ID|en,JA_ID|ja,FR_ID|fr,DE_ID|de,ES_ID|es,RU_ID|ru"
]
```

Good for one topic with multiple language subchannels.

In group mode, a message in any channel is translated to the other channels in the same group.

---

## Deployment model on macOS

`deploy.sh` generates local env files and installs LaunchAgents under:

- `~/Library/LaunchAgents/ai.mac-discord-translator.mirror-bot.plist`
- `~/Library/LaunchAgents/ai.mac-discord-translator.mlx-api.plist`

That means the stack can run persistently on a Mac without manually re-launching scripts every time.

---

## Discord requirements

At minimum, the mirror bot usually needs:

- View Channels
- Send Messages
- Read Message History
- Manage Webhooks (recommended)

And in Discord Developer Portal:

- **Message Content Intent**

If you use a separate reaction-based bot integration, you may also need additional reaction-related permissions and intents.

---

## What this repo intentionally excludes

This is a clean publishable repo. It does **not** include:

- `.env`
- secrets / bot tokens / SSH keys
- logs
- `node_modules`
- `.venv`
- downloaded models
- third-party upstream source trees

---

## Verified real-world use cases

This stack has already been used for:

- bilingual CN / EN mirrored channels
- private mirrored channels
- attachment/image mirroring
- a multilingual `off-topic` translation area with:
  - Chinese
  - English
  - Japanese
  - French
  - German
  - Spanish
  - Russian

---

## Recommended reading order

1. `docs/DISCORD_TRANSLATION_STACK_GUIDE.md`
2. `docs/MLX_SETUP_AND_MIGRATION.md`
3. `docs/MIRROR_BOT_SETUP_AND_MIGRATION.md`
4. `docs/REACTION_BOT_SETUP_AND_MIGRATION.md`

---

## Future improvements

Planned / likely next steps:

- stronger validation in the setup wizard
- optional OCR pipeline for images
- optional Discord slash-command based configuration helper
- optional support for additional translation backends
- packaging as a more polished reusable Mac app/server bundle

---

## Upstream note

A reaction-based translation bot can also be integrated into this stack.
That upstream source is **not redistributed here**, but the integration approach is documented.

See:

- `docs/REACTION_BOT_SETUP_AND_MIGRATION.md`
- `upstreams/README.md`
