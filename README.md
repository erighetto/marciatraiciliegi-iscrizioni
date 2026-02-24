# Marcia tra i ciliegi

Monorepo che contiene due progetti:

1) `desktop` -> applicazione desktop (Electron + React)
2) `mobile` -> applicazione mobile (Flutter Android)

## Stato attuale sviluppo

- Desktop avviato in `desktop/app` con:
  - setup Electron + React + TypeScript
  - flusso login/logout operatore (fase 2)
  - base UI sportello pronta per form iscrizione (fasi successive)
- Mobile avviato in `mobile/app` con:
  - setup Flutter (Android minSdk 26)
  - home con due flussi (`Leggi Tessera`, `Leggi Anagrafica`)
  - schermate placeholder operative per barcode/OCR + impostazioni

## Sviluppo senza Node.js/Flutter locali

Prerequisito unico: Docker + Docker Compose.

Comandi principali:

- `./scripts/desktop-dev.sh` -> avvia renderer React desktop su porta `5173`
- `FULL_ELECTRON=1 ./scripts/desktop-dev.sh` -> prova avvio Electron completo (richiede supporto GUI nel container)
- `./scripts/desktop-build.sh` -> build desktop
- `./scripts/mobile-analyze.sh` -> analisi Flutter
- `./scripts/mobile-test.sh` -> test Flutter
- `./scripts/mobile-run-web.sh` -> preview Flutter web su porta `8080`
- `./scripts/mobile-build-apk.sh` -> build APK Android

Nota pratica:
- Electron completo in container richiede configurazione display forwarding.
- Per Android reale/emulatore, normalmente si usa device con `adb` esterno o pipeline build APK in container.
