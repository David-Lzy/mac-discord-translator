#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

LANGS = {"zh", "en", "ja", "fr", "de", "es", "ru", "ko", "vi", "th", "id", "it", "pt"}
ID_RE = re.compile(r"^\d{8,32}$")


def fail(msg: str):
    print(f"CONFIG ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def warn(msg: str):
    print(f"CONFIG WARNING: {msg}", file=sys.stderr)


def validate_url(url: str, field: str):
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        fail(f"{field} must be a valid http/https URL, got: {url}")


def validate_group(entry: str):
    if ">" not in entry:
        fail(f"mirrorBot.channelGroups entry must look like group>CHANNEL|lang,... got: {entry}")
    group_name, members_raw = entry.split(">", 1)
    if not group_name.strip():
        fail(f"channel group name missing in: {entry}")
    members = [m.strip() for m in members_raw.split(",") if m.strip()]
    if len(members) < 2:
        fail(f"channel group must contain at least 2 channels: {entry}")
    seen_channels = set()
    seen_langs = set()
    for member in members:
        if "|" not in member:
            fail(f"group member must look like CHANNEL_ID|lang, got: {member}")
        channel_id, lang = [x.strip() for x in member.split("|", 1)]
        if not ID_RE.match(channel_id):
            fail(f"invalid Discord channel id in group: {channel_id}")
        if lang not in LANGS:
            fail(f"unsupported language code in group: {lang}")
        if channel_id in seen_channels:
            fail(f"duplicate channel id in group {group_name}: {channel_id}")
        if lang in seen_langs:
            warn(f"duplicate language code in group {group_name}: {lang}")
        seen_channels.add(channel_id)
        seen_langs.add(lang)


def validate_pair(entry: str):
    if ":" not in entry:
        fail(f"mirrorBot.channelPairs entry must look like EN_ID:ZH_ID, got: {entry}")
    left, right = [x.strip() for x in entry.split(":", 1)]
    if not ID_RE.match(left) or not ID_RE.match(right):
        fail(f"invalid Discord channel id in pair: {entry}")
    if left == right:
        fail(f"pair channels must be different: {entry}")


def main():
    if len(sys.argv) != 2:
        print("usage: validate-config.py <config.json>", file=sys.stderr)
        sys.exit(2)
    config_path = Path(sys.argv[1])
    if not config_path.exists():
        fail(f"config file not found: {config_path}")
    try:
        data = json.loads(config_path.read_text())
    except Exception as exc:
        fail(f"failed to parse JSON: {exc}")

    for key in ("discord", "translation", "mirrorBot"):
        if key not in data or not isinstance(data[key], dict):
            fail(f"missing required object: {key}")

    discord = data["discord"]
    translation = data["translation"]
    mirror = data["mirrorBot"]

    token = str(discord.get("botToken", "")).strip()
    guild_id = str(discord.get("guildId", "")).strip()
    if not token or token == "PUT_DISCORD_BOT_TOKEN_HERE":
        fail("discord.botToken is missing")
    if len(token) < 20:
        warn("discord.botToken looks unusually short")
    if not ID_RE.match(guild_id):
        fail(f"discord.guildId is missing or invalid: {guild_id}")
    if not isinstance(discord.get("webhookMode", True), bool):
        fail("discord.webhookMode must be true/false")
    if not isinstance(discord.get("mentionOriginalAuthor", False), bool):
        fail("discord.mentionOriginalAuthor must be true/false")

    vllm_base = str(translation.get("vllmBaseUrl", "")).strip()
    vllm_model = str(translation.get("vllmModel", "")).strip()
    if not vllm_base:
        fail("translation.vllmBaseUrl is missing")
    validate_url(vllm_base, "translation.vllmBaseUrl")
    if not vllm_model:
        fail("translation.vllmModel is missing")
    if not isinstance(translation.get("enableLocalMlxApi", False), bool):
        fail("translation.enableLocalMlxApi must be true/false")
    host = str(translation.get("mlxHost", "127.0.0.1")).strip()
    port = translation.get("mlxPort", 5010)
    if not host:
        fail("translation.mlxHost must not be empty")
    if not isinstance(port, int) or not (1 <= port <= 65535):
        fail(f"translation.mlxPort must be an integer 1-65535, got: {port}")
    if not str(translation.get("mlxModel", "")).strip():
        fail("translation.mlxModel must not be empty")

    groups = mirror.get("channelGroups", []) or []
    pairs = mirror.get("channelPairs", []) or []
    if not isinstance(groups, list) or not all(isinstance(x, str) for x in groups):
        fail("mirrorBot.channelGroups must be an array of strings")
    if not isinstance(pairs, list) or not all(isinstance(x, str) for x in pairs):
        fail("mirrorBot.channelPairs must be an array of strings")
    if not groups and not pairs:
        fail("mirrorBot.channelGroups and mirrorBot.channelPairs are both empty; configure at least one")
    for entry in groups:
        validate_group(entry)
    for entry in pairs:
        validate_pair(entry)

    print(f"CONFIG OK: {config_path}")
    print(f"  groups={len(groups)} pairs={len(pairs)} guildId={guild_id}")


if __name__ == "__main__":
    main()
