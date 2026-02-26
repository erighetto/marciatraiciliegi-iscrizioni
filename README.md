# Marcia tra i ciliegi

Monorepo che contiene due progetti:

1) `desktop` -> applicazione desktop (Electron + React)
2) `mobile` -> applicazione mobile (Flutter Android)

## Stato attuale sviluppo

- **Desktop** (`desktop/app`):
  - **Fasi 1–9 implementate:** setup, login/logout, form iscrizione con tariffario e validazione, pagamento contanti/digitale, consolidamento su Google Sheets (OAuth2), coda offline SQLite, storico "Le mie transazioni" con export PDF/CSV, usabilità e documentazione build. Vedi `desktop/DEVELOPMENT-PLAN.md` e `desktop/README.md`.
- **Mobile** (`mobile/app`):
  - **Fase 1 completata:** setup Flutter (Android minSdk 26), struttura `lib/screens`, `lib/services`, `lib/models`, tema e route.
  - **Fase 2 parziale:** schermata Impostazioni (operatore, ID/URL foglio) presente; **mancano** OAuth 2.0 Google e persistenza impostazioni (da integrare con `shared_preferences`/`flutter_secure_storage`).
  - **Fasi 3–4 implementate:** Leggi Tessera con **fotocamera** e **mobile_scanner** (barcode), conferma FIASP/UMV e fallback inserimento manuale; Leggi Anagrafica con **fotocamera** (image_picker), **ML Kit OCR** (latino), parsing e schermata revisione. Invio in coda locale; **manca** sync su Google Sheets (Fase 5).
  - **Fase 5 parziale:** modello `AcquisitionRecord` e `SyncQueueService` in-memory presenti; **mancano** SQLite per coda offline, Google Sheets API e sync.
  - **Fase 6 parziale:** home con due pulsanti, accesso Impostazioni e indicatore stato; **mancano** lettura impostazioni persistenti e collegamento alla coda di sync.
  - Dettaglio: `mobile/DEVELOPMENT-PLAN.md` e `mobile/README.md`.

## Sviluppo senza Node.js/Flutter locali

Prerequisito unico: Docker + Docker Compose.

Comandi principali:

- `./scripts/desktop-dev.sh` -> avvia solo il renderer React in Docker su porta `5173`
- `FULL_ELECTRON=1 ./scripts/desktop-dev.sh` -> avvia Electron + renderer **in locale** (non in Docker; serve Node/npm installati). Necessario per usare “Consolida” e Google Sheets.
- `./scripts/desktop-build.sh` -> build desktop
- `./scripts/mobile-analyze.sh` -> analisi Flutter
- `./scripts/mobile-test.sh` -> test Flutter
- `./scripts/mobile-run-web.sh` -> preview Flutter web su porta `8080`
- `./scripts/mobile-build-apk.sh` -> build APK Android
- `./scripts/mobile-adb-connect.sh` -> connette ADB a BlueStacks sulla host (prerequisito: adb in PATH). Per eseguire l’app sull’emulatore serve Flutter in locale: `cd mobile/app && flutter run`.

Nota pratica:
- Con `FULL_ELECTRON=1` lo script esce da Docker e avvia l’app sul tuo PC (Electron richiede display e librerie grafiche, non disponibili nel container). Assicurati di avere Node.js e npm installati in locale.
- Per Android reale/emulatore, normalmente si usa device con `adb` esterno o pipeline build APK in container.
