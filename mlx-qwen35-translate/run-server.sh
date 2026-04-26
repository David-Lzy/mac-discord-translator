#!/usr/bin/env bash
set -euo pipefail
cd /Users/davidli/.openclaw/workspace/scripts/mlx-qwen35-translate
source .venv/bin/activate
export MLX_TRANSLATE_HOST="127.0.0.1"
export MLX_TRANSLATE_PORT="5010"
export MLX_TRANSLATE_MODEL="mlx-community/Qwen3.5-0.8B-4bit"
exec python server.py
