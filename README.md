# Foundation Discord Translation Stack

A cleaned-up, publishable version of the local Discord translation workflow used for the Foundation community server.

This repo focuses on the **practical pieces that make the system run**:

- a local MLX-based translation API wrapper
- a Discord mirror bot for bilingual or multilingual channel syncing
- setup / migration / deployment documentation
- integration notes for a reaction-based translation bot

---

## What this project can do

### 1. Local translation API
`mlx-qwen35-translate/`

Runs a local MLX model on Apple Silicon and exposes a **LibreTranslate-compatible** HTTP API.

Current API shape:

- `GET /health`
- `GET /languages`
- `POST /translate`

This makes it easy to plug into other bots or translation workflows without coupling them to a specific model implementation.

### 2. Discord mirror bot
`discord-mirror-bot/`

A custom Discord bot that listens to human messages and republishes translated content into linked channels.

Supported modes:

- **1:1 language pairs**
  - example: English ↔ Chinese
- **multilingual channel groups**
  - example: one `off-topic` topic split into `zh / en / ja / fr / de / es / ru`
- **attachment forwarding**
  - images and attachments are mirrored too
- **webhook sender mirroring**
  - messages can appear with the original sender name/avatar for a cleaner chat experience

### 3. Ops / migration docs
`docs/`

Includes practical notes for:

- local setup
- Discord bot permissions and intents
- environment variables
- migration to another machine
- recovery / troubleshooting

---

## Architecture

### Reaction translation path

```text
Discord reaction
  -> reaction bot (.NET / upstream integration)
  -> local LibreTranslate-compatible API
  -> translated reply
```

### Mirror translation path

```text
Discord message in source channel
  -> custom mirror bot
  -> OpenAI-compatible / vLLM-compatible translation endpoint
  -> translated message in sibling channel(s)
```

---

## Repository layout

```text
foundation-discord-translation-stack/
├── README.md
├── .gitignore
├── docs/
│   ├── DISCORD_TRANSLATION_STACK_GUIDE.md
│   ├── MLX_SETUP_AND_MIGRATION.md
│   ├── MIRROR_BOT_SETUP_AND_MIGRATION.md
│   └── REACTION_BOT_SETUP_AND_MIGRATION.md
├── mlx-qwen35-translate/
│   ├── server.py
│   ├── run-server.sh
│   ├── restart-service.sh
│   ├── stop-service.sh
│   └── README.md
├── discord-mirror-bot/
│   ├── index.js
│   ├── package.json
│   ├── package-lock.json
│   ├── .env.example
│   └── README.md
└── upstreams/
    └── README.md
```

---

## What is intentionally excluded

This repo is a **clean export**, so it does **not** include:

- `.env`
- bot tokens / API keys / SSH keys
- logs
- `node_modules`
- `.venv`
- downloaded models
- third-party upstream source trees

That keeps the repo safe to publish and easier to understand.

---

## Quick start

### A. Run the local translation API

```bash
cd mlx-qwen35-translate
./run-server.sh
```

Then verify:

```bash
curl -sS http://127.0.0.1:5010/health
```

### B. Run the mirror bot

```bash
cd discord-mirror-bot
cp .env.example .env
npm install
node index.js
```

Then configure your Discord bot token, guild id, and either:

- `MIRROR_CHANNEL_PAIRS`
- or `MIRROR_CHANNEL_GROUPS`

---

## Example configurations

### 1:1 pair mode

```env
MIRROR_CHANNEL_PAIRS=EN_CHANNEL_ID:ZH_CHANNEL_ID
```

### Multilingual group mode

```env
MIRROR_CHANNEL_GROUPS=offtopic>CHANNEL_ID|zh,CHANNEL_ID|en,CHANNEL_ID|ja,CHANNEL_ID|fr,CHANNEL_ID|de,CHANNEL_ID|es,CHANNEL_ID|ru
```

In group mode, a message in any one channel is translated to the other channels in the same group.

---

## Discord permissions / intents

At minimum, the mirror bot typically needs:

- View Channels
- Send Messages
- Read Message History
- Manage Webhooks (recommended)

And in the Discord Developer Portal:

- **Message Content Intent**

---

## Verified use case

This stack has already been used to run a real multilingual Discord workflow, including:

- standard bilingual CN / EN mirrored channels
- private mirrored channels
- a dedicated multilingual `off-topic` translation area with:
  - Chinese
  - English
  - Japanese
  - French
  - German
  - Spanish
  - Russian

---

## Related / upstream notes

The reaction-based translation bot used in the original local setup is based on an upstream .NET project.
That upstream source tree is **not redistributed here**, but the integration approach is documented.

See:

- `docs/REACTION_BOT_SETUP_AND_MIGRATION.md`
- `upstreams/README.md`

---

## Recommended reading order

If you want the fastest path:

1. `docs/DISCORD_TRANSLATION_STACK_GUIDE.md`
2. `docs/MLX_SETUP_AND_MIGRATION.md`
3. `docs/MIRROR_BOT_SETUP_AND_MIGRATION.md`
4. `docs/REACTION_BOT_SETUP_AND_MIGRATION.md`

---

## License / publishing note

This repository contains original glue code, wrappers, and documentation prepared from a private local working setup.
Any upstream third-party projects should be obtained from their original repositories and used under their own licenses.
