# Specifiche Funzionali — App Gestione Iscrizioni Evento Podistico

## 1. Panoramica del Sistema

L'applicazione è un client desktop multipiattaforma (macOS e Windows) sviluppato con Electron. Più postazioni operative possono lavorare simultaneamente, condividendo un unico registro centralizzato su Google Drive. Ogni operazione è tracciabile per operatore.

---

## 2. Autenticazione Operatore

All'avvio dell'applicazione viene presentata una schermata di login minimale: l'operatore inserisce il proprio nominativo (nome e cognome o codice identificativo). Non è prevista una password, ma il nominativo viene associato a tutte le transazioni generate nella sessione. La sessione rimane attiva fino alla chiusura dell'applicazione o a un esplicito logout.

---

## 3. Schermata Principale — Registrazione Iscrizione

### 3.1 Dati di input

L'operatore compila i seguenti campi per ciascun gruppo di partecipanti che si presenta allo sportello:

- **Numero totale partecipanti** (campo numerico)
- Di cui **tesserati FIASP/UMV** (campo numerico, ≤ totale partecipanti)
- Di cui **con riconoscimento/dono promozionale** (campo numerico, ≤ totale partecipanti)

Il sistema deduce automaticamente i non tesserati come differenza tra il totale e i tesserati.

### 3.2 Tariffario

| Tipologia | Tesserati FIASP/UMV | Non tesserati |
|---|---|---|
| Senza dono promozionale | € 2,50 | € 3,50 |
| Con dono promozionale | € 4,00 | € 5,00 |

La maggiorazione di € 1,00 per i non soci si applica in entrambe le fasce.

### 3.3 Calcolo automatico

Il sistema calcola in tempo reale, aggiornando i valori ad ogni modifica dei campi:

- Subtotale tesserati senza dono
- Subtotale tesserati con dono
- Subtotale non tesserati senza dono
- Subtotale non tesserati con dono
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

- Codice progetto avviato in `desktop/app`.
- Fase 1 completata: setup React + Electron + script build/distribuzione.
- Fase 2 avviata: login operatore senza password + logout + shell schermata principale.

Comandi (Docker-only, dalla root del monorepo):
- `./scripts/desktop-dev.sh`
- `./scripts/desktop-build.sh`
