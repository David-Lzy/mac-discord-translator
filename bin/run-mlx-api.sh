#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO_ROOT/config/generated/mlx-api.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE. Run ./bin/deploy.sh first." >&2
  exit 1
fi
set -a
source "$ENV_FILE"
set +a
cd "$REPO_ROOT/mlx-qwen35-translate"
source .venv/bin/activate
exec python server.py
