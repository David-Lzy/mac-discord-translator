# Discord Permissions & Intent Checklist

Use this checklist before blaming the local scripts.
A large percentage of deployment failures come from Discord-side permissions or missing intents.

---

## 1. Bot invite / server presence

Confirm the bot is actually in the target server.

Check:

- the bot appears in the member list
- the bot can see the target category / channels
- the bot is not blocked by role overrides

---

## 2. Required channel permissions

For the mirror bot, the safest baseline is:

- View Channels
- Send Messages
- Read Message History
- Attach Files
- Embed Links (recommended)
- Manage Webhooks (recommended)

If webhook-based sender mirroring is enabled, **Manage Webhooks** is important.
If you do not want to grant that permission, set:

- `discord.webhookMode = false`

in `config/config.local.json`.

---

## 3. Required Discord Developer Portal settings

In the Bot page of your Discord application, enable:

- **Message Content Intent**

Without this, the mirror bot may log in successfully but still fail to read normal message text.

If you also use a reaction-based translation bot, make sure its required reaction-related intents are enabled too.

---

## 4. Channel mapping sanity check

Before deploy, make sure every channel id in your config is real.

### Pair mode

Example:

```json
"channelPairs": [
  "123456789012345678:234567890123456789"
]
```

### Group mode

Example:

```json
"channelGroups": [
  "offtopic>123|zh,456|en,789|ja"
]
```

Common mistakes:

- pasting a category id instead of a text channel id
- using a channel id from another server
- malformed group syntax
- duplicate ids in a group

Run:

```bash
./bin/deploy.sh --dry-run
```

first.

---

## 5. Translation backend sanity check

The mirror bot also depends on your translation endpoint.

Check:

- `translation.vllmBaseUrl` is reachable
- `translation.vllmModel` is correct for that backend
- if `enableLocalMlxApi=true`, your local MLX API can actually start on the configured port

For the local MLX API:

```bash
curl -sS http://127.0.0.1:5010/health
```

---

## 6. Human test rule

The mirror bot ignores bot-authored messages on purpose.

So final testing should always be done with:

- a real human account
- in a real configured source channel

Do not rely on the bot talking to itself as an end-to-end test.

---

## 7. Best-practice deployment order

Recommended sequence:

1. Confirm Discord bot token is valid
2. Confirm server invite and permissions
3. Enable Message Content Intent
4. Fill `config/config.local.json`
5. Run `./bin/deploy.sh --dry-run`
6. Run `./bin/deploy.sh`
7. Run `./bin/status.sh`
8. Test with a real user message

---

## 8. If something still fails

Check these in order:

1. `./bin/status.sh`
2. `discord-mirror-bot/mirror-bot.log`
3. LaunchAgent status via `launchctl print`
4. translation endpoint health
5. Discord permissions / intents again

The boring answer is often the right one here: permissions, intents, or a bad channel id.
