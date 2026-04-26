# MLX Translate API

Local translation API for `mlx-community/Qwen3.5-0.8B-4bit`.

## Endpoints

- `GET http://127.0.0.1:5010/health`
- `GET http://127.0.0.1:5010/languages`
- `POST http://127.0.0.1:5010/translate`

Example:

```bash
curl -sS -X POST http://127.0.0.1:5010/translate \
  -H 'Content-Type: application/json' \
  -d '{"q":"Hello, how are you today?","source":"en","target":"zh"}'
```

Response shape is LibreTranslate-compatible:

```json
{
  "translatedText": "你好，今天过得怎么样？",
  "detectedLanguage": { "language": "en" }
}
```

## Startup

This service is installed as a macOS user LaunchAgent:

- `~/Library/LaunchAgents/ai.openclaw.mlx-translate-api.plist`

It auto-starts when David logs in and restarts if it exits.

## Logs

- `/Users/davidli/.openclaw/workspace/scripts/mlx-qwen35-translate/server.stdout.log`
- `/Users/davidli/.openclaw/workspace/scripts/mlx-qwen35-translate/server.stderr.log`

## Control

```bash
./restart-service.sh
./stop-service.sh
```
