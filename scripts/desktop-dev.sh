#!/usr/bin/env bash
set -euo pipefail

dev_command="npm run dev:renderer"
if [[ "${FULL_ELECTRON:-0}" == "1" ]]; then
  dev_command="npm run dev"
fi

docker compose run --rm --service-ports desktop bash -lc "npm install && ${dev_command}"
