#!/usr/bin/env python3
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

TEXT_CHANNEL_TYPES = {0}


def fail(msg: str, code: int = 1):
    print(f"DISCORD CHECK ERROR: {msg}", file=sys.stderr)
    sys.exit(code)


def get_json(url: str, token: str):
    req = urllib.request.Request(url, headers={"Authorization": f"Bot {token}", "User-Agent": "mac-discord-translator/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="ignore")
        fail(f"HTTP {exc.code} when calling Discord API {url}: {body[:300]}")
    except Exception as exc:
        fail(f"Failed to call Discord API {url}: {exc}")


def collect_channel_ids(mirror: dict):
    ids = []
    for entry in mirror.get("channelPairs", []) or []:
        left, right = [x.strip() for x in entry.split(":", 1)]
        ids.extend([left, right])
    for entry in mirror.get("channelGroups", []) or []:
        _, members = entry.split(">", 1)
        for member in [m.strip() for m in members.split(",") if m.strip()]:
            channel_id, _lang = [x.strip() for x in member.split("|", 1)]
            ids.append(channel_id)
    return ids


def main():
    if len(sys.argv) != 2:
        print("usage: check-discord-config.py <config.json>", file=sys.stderr)
        sys.exit(2)
    config_path = Path(sys.argv[1])
    if not config_path.exists():
        fail(f"Config not found: {config_path}")
    cfg = json.loads(config_path.read_text())
    token = cfg["discord"]["botToken"]
    guild_id = cfg["discord"]["guildId"]
    channel_ids = collect_channel_ids(cfg["mirrorBot"])

    me = get_json("https://discord.com/api/v10/users/@me", token)
    channels = get_json(f"https://discord.com/api/v10/guilds/{guild_id}/channels", token)
    channel_map = {str(ch["id"]): ch for ch in channels}

    missing = []
    wrong_type = []
    print(f"DISCORD CHECK OK: authenticated as {me.get('username')}#{me.get('discriminator', '0')} in guild {guild_id}")
    for cid in channel_ids:
        ch = channel_map.get(str(cid))
        if not ch:
            missing.append(cid)
            continue
        ctype = ch.get("type")
        if ctype not in TEXT_CHANNEL_TYPES:
            wrong_type.append((cid, ctype, ch.get("name")))
            continue
        print(f"  channel ok: {cid} -> #{ch.get('name')}")

    if missing:
        fail("Configured channel IDs not found in guild or not visible to bot: " + ", ".join(missing))
    if wrong_type:
        details = ", ".join(f"{cid} ({name}, type={ctype})" for cid, ctype, name in wrong_type)
        fail("Configured channel IDs must point to standard text channels: " + details)

    print(f"  verified {len(channel_ids)} channel references")


if __name__ == "__main__":
    main()
