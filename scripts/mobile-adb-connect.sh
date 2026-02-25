#!/usr/bin/env bash
# Connette ADB all'emulatore BlueStacks (o altro emulatore) sulla HOST.
# Va lanciato dalla tua macchina, NON da Docker: BlueStacks gira sulla host,
# quindi adb deve girare sulla host per vedere localhost:5555.
#
# Prerequisito: adb in PATH (Android Studio, oppure: brew install android-platform-tools)
set -euo pipefail

PORT="${1:-5555}"
if ! command -v adb &>/dev/null; then
  echo "Errore: 'adb' non trovato in PATH."
  echo "Installa Android Platform Tools (es. Android Studio) oppure: brew install android-platform-tools"
  exit 1
fi
echo "Connessione a BlueStacks su localhost:${PORT}..."
adb connect "localhost:${PORT}"
echo "Dispositivi:"
adb devices -l
