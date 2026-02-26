#!/usr/bin/env bash
set -euo pipefail

cd "$(cd "$(dirname "$0")/.." && pwd)"

docker compose run --rm desktop bash -lc "npm install && npm run dist"

