#!/usr/bin/env bash
set -euo pipefail

docker compose run --rm desktop bash -lc "npm install && npm run build"
