#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "${FULL_ELECTRON:-0}" == "1" ]]; then
  # Electron richiede librerie grafiche e display: avvia in locale, non in Docker
  echo "Avvio desktop con Electron in locale (Docker non supporta la GUI di Electron)..."
  cd "${REPO_ROOT}/desktop/app"
  npm install && npm run dev
else
  cd "${REPO_ROOT}"
  docker compose run --rm --service-ports desktop bash -lc "npm install && npm run dev:renderer"
fi
