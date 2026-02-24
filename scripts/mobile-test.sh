#!/usr/bin/env bash
set -euo pipefail

docker compose run --rm mobile bash -lc "flutter pub get && flutter test"
