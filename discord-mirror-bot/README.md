# Discord Mirror Bot

A traditional Discord relay bot for one or more translation groups.

It listens for human messages, translates them with the local vLLM endpoint, and reposts them to the paired channel or multilingual sibling channels.

## Why this bot

Unlike the OpenClaw assistant flow, this relay bot:

- preserves who sent the message
- does not behave like a chat assistant
- only does channel listener -> translation -> repost
- can be pinned to the local vLLM model only

## Setup

1. Create a dedicated Discord bot/app if possible.
2. Give it access to the target server.
3. Required permissions:
   - View Channels
   - Send Messages
   - Read Message History
   - Manage Webhooks (recommended, for sender-name mirroring)
4. Enable **Message Content Intent** in the Discord developer portal.
5. Copy `.env.example` to `.env` and fill in the token plus one of:
   - multilingual groups via `MIRROR_CHANNEL_GROUPS` using `GROUP>CHANNEL_ID|lang,CHANNEL_ID|lang`
   - multiple pairs via `MIRROR_CHANNEL_PAIRS` using `EN_ID:ZH_ID;EN_ID:ZH_ID`
   - one pair via `MIRROR_EN_CHANNEL_ID` + `MIRROR_ZH_CHANNEL_ID`
6. Install dependencies:

```bash
cd /Users/davidli/.openclaw/workspace/scripts/discord-mirror-bot
npm install
```

7. Run:

```bash
node index.js
```

## Notes

- Recommended: use a **separate bot token**, not the same token as OpenClaw.
- `MIRROR_CHANNEL_GROUPS` takes precedence over pair config.
- `MIRROR_CHANNEL_PAIRS` takes precedence over the single-pair env vars when no groups are set.
- If `WEBHOOK_MODE=true`, the bot reposts using channel webhooks so the translated message shows the original sender name/avatar more naturally.
- If webhook creation is not allowed, set `WEBHOOK_MODE=off` and it will post as a normal bot message with the sender name prepended.
- The relay marker prevents loops on relayed messages.
