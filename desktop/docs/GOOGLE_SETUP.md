# Configurazione Google Sheets e OAuth2

Per salvare le iscrizioni su un foglio Google condiviso serve un progetto Google Cloud con l’API Google Sheets abilitata e credenziali OAuth 2.0 per “Desktop app”.

## 1. Progetto Google Cloud

1. Vai alla [Console Google Cloud](https://console.cloud.google.com/).
2. Crea un nuovo progetto (o usane uno esistente).
3. Abilita **Google Sheets API**: menu “API e servizi” → “Libreria” → cerca “Google Sheets API” → Abilita.

## 2. Credenziali OAuth “Desktop app”

1. In “API e servizi” → “Credenziali” → “Crea credenziali” → “ID client OAuth”.
2. Tipo applicazione: **Applicazione desktop**.
3. Nome: ad es. “Marcia tra i ciliegi – Desktop”.
4. Crea e annota **ID client** e **Segreto client**.

## 3. Variabili d’ambiente

Imposta prima di avviare l’app (o in un file `.env` se supportato):

- `GOOGLE_CLIENT_ID` — ID client OAuth.
- `GOOGLE_CLIENT_SECRET` — Segreto client OAuth.
- `GOOGLE_SHEET_ID` — ID del foglio (dall’URL: `https://docs.google.com/spreadsheets/d/QUESTO_È_L_ID/edit`).
- `GOOGLE_SHEET_RANGE` (opzionale) — Intervallo in notazione A1, es. `Foglio1!A:L`. Default: `Foglio1!A:L`.

**Importante:** il file `.env` va creato in **`desktop/app/.env`** (non in `mobile/`). L'app lo carica solo se avviata con Electron. In sviluppo, dalla root del monorepo: **`FULL_ELECTRON=1 ./scripts/desktop-dev.sh`**.

## 4. Primo avvio del foglio

Il foglio deve avere almeno una riga (può essere intestazione). Le colonne scritte in append sono, in ordine:

- Timestamp  
- Nominativo operatore  
- Postazione  
- Totale partecipanti  
- Tesserati con dono  
- Tesserati senza dono  
- Non tesserati con dono  
- Non tesserati senza dono  
- Totale importo  
- Modalità pagamento  
- Importo ricevuto (se contanti)  
- Resto (se contanti)  

L’app scrive sempre in **append** (nuove righe in coda), senza sovrascrivere.

## 5. Autorizzazione nell’app

All’avvio, se non risultano token salvati, l’app mostra “Collega account Google”. Cliccando si apre una finestra per accedere con l’account Google che ha accesso al foglio. I token sono salvati in modo cifrato nel keychain di sistema (macOS/Windows).
