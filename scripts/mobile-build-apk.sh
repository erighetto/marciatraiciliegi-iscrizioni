#!/usr/bin/env bash
set -euo pipefail

# Precache scarica gli artifact dell'engine per l'architettura del container
# (necessario su host ARM64 es. Mac M1/M2, dove il container è linux-arm64)
docker compose run --rm mobile bash -lc "\
  flutter pub get && \
  flutter precache --android --no-web --no-ios && \
  flutter build apk"
