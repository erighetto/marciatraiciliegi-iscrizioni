#!/usr/bin/env bash
set -euo pipefail

docker compose run --rm --service-ports mobile \
  bash -lc "flutter pub get && flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080"
