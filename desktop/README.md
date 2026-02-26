# Specifiche Funzionali — App Gestione Iscrizioni Evento Podistico

## 1. Panoramica del Sistema

L'applicazione è un client desktop multipiattaforma (macOS e Windows) sviluppato con Electron. Più postazioni operative possono lavorare simultaneamente, condividendo un unico registro centralizzato su Google Drive. Ogni operazione è tracciabile per operatore.

---

## 2. Autenticazione Operatore

All'avvio dell'applicazione viene presentata una schermata di login minimale: l'operatore inserisce il proprio nominativo (nome e cognome o codice identificativo). Non è prevista una password, ma il nominativo viene associato a tutte le transazioni generate nella sessione. La sessione rimane attiva fino alla chiusura dell'applicazione o a un esplicito logout.

---

## 3. Schermata Principale — Registrazione Iscrizione

### 3.1 Dati di input

Per ogni gruppo di partecipanti che si presenta allo sportello l'operatore inserisce **quattro numeri** che identificano univocamente la composizione (e permettono di ricostruire per ogni partecipante se era tesserato o meno e se ha scelto il biglietto con o senza dono):

- **Tesserati FIASP/UMV con dono promozionale** (numerico, ≥ 0)
- **Tesserati FIASP/UMV senza dono** (numerico, ≥ 0)
- **Non tesserati con dono promozionale** (numerico, ≥ 0)
- **Non tesserati senza dono** (numerico, ≥ 0)

Il **numero totale partecipanti** è la somma dei quattro valori (calcolata e mostrata in sola lettura). Validazione: la somma deve essere > 0; tutti i campi ≥ 0.

### 3.2 Tariffario

| Tipologia | Tesserati FIASP/UMV | Non tesserati |
|---|---|---|
| Senza dono promozionale | € 2,50 | € 3,50 |
| Con dono promozionale | € 4,00 | € 5,00 |

La maggiorazione di € 1,00 per i non soci si applica in entrambe le fasce.

### 3.3 Calcolo automatico

Il sistema calcola in tempo reale, ad ogni modifica dei quattro campi:

- Totale partecipanti (somma dei quattro gruppi)
- Subtotale per ogni gruppo (quantità × prezzo unitario secondo il tariffario)
- **Totale dovuto** (somma dei quattro subtotali)

### 3.4 Gestione pagamento

L'operatore seleziona la modalità di pagamento tramite un selettore ben visibile:

**Pagamento in contanti:** compare il campo "Importo ricevuto". Il sistema calcola e mostra il resto (Importo ricevuto − Totale dovuto). Se l'importo ricevuto è inferiore al dovuto, il sistema segnala l'anomalia impedendo la conferma.

**Pagamento digitale (POS/bonifico/altro):** i campi di importo ricevuto e resto vengono nascosti o disabilitati. Il totale è considerato automaticamente saldato.

---

## 4. Consolidamento della Transazione

Il pulsante **"Consolida"** diventa attivo solo quando tutti i campi obbligatori sono compilati correttamente e il pagamento risulta coerente. Alla pressione:

1. Il sistema compone un record strutturato con i seguenti campi: timestamp (data e ora), nominativo operatore, postazione, numero partecipanti totali, numero tesserati, numero con dono, totale importo, modalità pagamento, importo ricevuto (se contanti), resto (se contanti).
2. Il record viene accodato al file di calcolo condiviso su Google Drive (formato `.xlsx` o Google Sheets nativo).
3. In caso di errore di scrittura (connettività assente, conflitto di accesso), la transazione viene salvata localmente in una coda e un indicatore visivo avvisa l'operatore. Il sistema ritenta la sincronizzazione automaticamente non appena la connessione è ripristinata.
4. Dopo il consolidamento con successo, la schermata si azzera e torna pronta per una nuova iscrizione.

### 4.1 Gestione della concorrenza

Poiché più postazioni possono scrivere simultaneamente sullo stesso file, il sistema adotta una strategia di **append atomico**: ogni postazione aggiunge righe in coda senza sovrascrivere quelle esistenti. Si raccomanda l'uso delle API di Google Sheets (append row) che gestiscono nativamente la concorrenza in scrittura, evitando conflitti di sovrascrittura tipici dei file `.xlsx` condivisi.

---

## 5. Storico Transazioni

Dal menu principale è accessibile la voce **"Le mie transazioni"**, che mostra una vista filtrata del registro condiviso: vengono visualizzate esclusivamente le righe associate al nominativo dell'operatore correntemente in sessione. La vista include colonne per data/ora, numero partecipanti, importo, modalità di pagamento e stato di sincronizzazione. È previsto un filtro per data e la possibilità di esportare la vista filtrata in PDF o CSV.

---

## 6. Requisiti Non Funzionali

**Connettività.** L'app deve funzionare in modalità degradata (solo coda locale) in assenza di connessione Internet, garantendo che nessuna transazione vada persa.

**Usabilità.** L'interfaccia è progettata per un uso rapido da sportello: font grandi, contrasto elevato, navigazione possibile anche solo da tastiera con tasto Tab e invio tramite Enter. Il flusso deve completarsi in meno di 30 secondi per un gruppo standard.

**Multipiattaforma.** Il pacchetto di distribuzione include installer `.dmg` per macOS e `.exe` (NSIS o Squirrel) per Windows.

**Sicurezza.** Le credenziali OAuth2 per Google Drive sono conservate nel keychain di sistema (Keychain su macOS, Credential Manager su Windows) e non in file di testo in chiaro.

**Tracciabilità.** Ogni record nel file condiviso è immutabile una volta scritto. Eventuali correzioni avvengono tramite una nuova riga di rettifica, non sovrascrivendo il record originale.

---

## 7. Stack Tecnologico Consigliato

- **Framework:** Electron con renderer in React o Vue
- **Storage locale:** SQLite (via `better-sqlite3`) per la coda offline
- **Integrazione cloud:** Google Sheets API v4 (append atomico) con autenticazione OAuth2
- **Build & distribuzione:** `electron-builder` per generare i pacchetti per entrambe le piattaforme

---

## Avanzamento implementazione

- Codice progetto in `desktop/app`.
- **Fasi 1–9 implementate:** setup, login/logout, form iscrizione con tariffario e validazione, pagamento contanti/digitale, consolidamento su Google Sheets (OAuth2, append), coda offline SQLite con retry, storico "Le mie transazioni" con filtro data ed export PDF/CSV, usabilità (font, contrasto, Tab/Enter), build e documentazione. Dettaglio in [DEVELOPMENT-PLAN.md](./DEVELOPMENT-PLAN.md).

### Comandi (Docker, dalla root del monorepo)

- `./scripts/desktop-dev.sh` — avvio renderer React su porta 5173
- `FULL_ELECTRON=1 ./scripts/desktop-dev.sh` — avvio Electron completo (richiede GUI nel container)
- `./scripts/desktop-build.sh` — build desktop

### Build e distribuzione

Dalla cartella `desktop/app`:

- **Build dell’app (renderer + bundle):**  
  `npm run build`  
  Compila TypeScript e produce la build Vite in `dist/`.

- **Generazione installer:**  
  `npm run dist`  
  Esegue `npm run build` e poi `electron-builder`, senza pubblicazione. Gli installer vengono creati in:
  - **macOS:** `desktop/app/release/*.dmg`
  - **Windows:** `desktop/app/release/*.exe` (installer NSIS)

Per il **code signing** (firma dell’app su macOS/Windows), configurare le variabili d’ambiente richieste da `electron-builder` (es. `CSC_LINK`, `CSC_KEY_PASSWORD` per macOS; certificato Windows per .exe). Vedi la [documentazione electron-builder](https://www.electron.build/code-signing).

Configurazione **Google Sheets e OAuth2** per il consolidamento e lo storico: vedi [docs/GOOGLE_SETUP.md](docs/GOOGLE_SETUP.md).
