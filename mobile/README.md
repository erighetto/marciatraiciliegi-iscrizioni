# Specifiche Funzionali – App Android di Acquisizione Dati

## 1. Panoramica del Sistema

L'applicazione è un tool mobile per operatori che permette di acquisire dati anagrafici tramite due modalità (barcode e OCR su scritte a mano) e di consolidarli su un foglio Google Sheets. L'app viene sviluppata senza Android Studio, utilizzando un framework alternativo (es. **MIT App Inventor**, **Flutter via terminale**, o **Kivy/Python con Buildozer**).

---

## 2. Architettura Generale

L'app si compone di tre macro-moduli:

**Modulo di acquisizione** → **Modulo di revisione operatore** → **Modulo di consolidamento su GDrive**

Ogni flusso è indipendente ma condivide lo stesso layer di scrittura su Google Sheets.

---

## 3. Flusso Tipo A – Acquisizione Barcode

### 3.1 Attivazione scanner
L'operatore seleziona la modalità "Leggi Tessera" dalla schermata principale. La fotocamera si attiva in modalità scanner continuo. Il sistema supporta i formati barcode più comuni (QR, Code128, Code39, EAN).

### 3.2 Rilevamento e acquisizione
Non appena un barcode viene riconosciuto, il sistema congela l'immagine, emette un feedback sonoro/vibrazione e mostra il valore decodificato del codice.

### 3.3 Classificazione tessera
Il sistema presenta all'operatore una schermata di conferma con il codice letto e due pulsanti di scelta esclusiva: **FIASP** oppure **UMV**. L'operatore non può procedere senza selezionare una delle due opzioni.

### 3.4 Conferma e salvataggio
Dopo la selezione, l'operatore preme "Conferma". Il sistema invia al foglio di calcolo una riga con: timestamp, codice barcode, tipo tessera (FIASP/UMV), identificativo operatore.

### 3.5 Gestione errori
Se il barcode non è leggibile dopo N secondi, il sistema propone un'acquisizione manuale del codice tramite tastiera. Se la scrittura su Sheets fallisce, il record viene salvato localmente in coda e ritentato alla connessione successiva.

---

## 4. Flusso Tipo B – Acquisizione OCR su scrittura a mano

### 4.1 Attivazione fotocamera
L'operatore seleziona la modalità "Leggi Anagrafica". La fotocamera si attiva in modalità foto statica. Una guida visiva (riquadro di ritaglio) aiuta l'operatore a inquadrare correttamente il testo.

### 4.2 Acquisizione immagine
L'operatore scatta la foto. Il sistema invia l'immagine al motore OCR (Google ML Kit on-device o Google Cloud Vision API) specificando che il contenuto atteso è testo manoscritto in italiano.

### 4.3 Parsing del risultato OCR
Il sistema applica una logica di parsing sul testo grezzo restituito dall'OCR per tentare di identificare tre campi: **Nome**, **Cognome**, **Data di nascita** (formati attesi: GG/MM/AAAA, GG-MM-AAAA, testo esteso). Il parser può essere guidato dalla posizione relativa delle righe o da keyword contestuali (es. "nato il", "cognome:").

### 4.4 Schermata di revisione operatore
Il sistema presenta una schermata con tre campi editabili pre-compilati con quanto rilevato dall'OCR. I campi con bassa confidenza di riconoscimento vengono evidenziati visivamente (es. bordo arancione). L'operatore può modificare liberamente qualsiasi campo prima di confermare.

### 4.5 Conferma e salvataggio
L'operatore preme "Conferma". Il sistema invia al foglio di calcolo una riga con: timestamp, nome, cognome, data di nascita, flag "dato OCR modificato" (booleano, utile per analisi qualità), identificativo operatore.

### 4.6 Gestione errori
Se l'OCR non produce output (immagine troppo scura, mossa o illeggibile), il sistema lo segnala e offre tre opzioni: ritenta la foto, inserimento completamente manuale, annulla.

---

## 5. Modulo di Consolidamento su Google Sheets

### 5.1 Struttura del foglio
Il foglio su Google Drive contiene due tab separati: **"Tessere"** (dati Tipo A) e **"Anagrafiche"** (dati Tipo B). Le colonne sono fisse e documentate in un tab "Legenda".

**Tab Tessere:** Timestamp | Operatore | Codice Barcode | Tipo Tessera | Metodo inserimento

**Tab Anagrafiche:** Timestamp | Operatore | Nome | Cognome | Data di Nascita | OCR Modificato | Metodo inserimento

### 5.2 Autenticazione
L'app si autentica su Google Sheets tramite OAuth 2.0 (account Google autorizzato al foglio). Le credenziali vengono memorizzate localmente dopo il primo accesso e rinnovate automaticamente.

### 5.3 Modalità offline
In assenza di connessione, i record vengono accodati in un database locale (SQLite). Un indicatore visivo mostra all'operatore quanti record sono in attesa di sincronizzazione. La sincronizzazione avviene automaticamente al ripristino della connessione, o manualmente tramite apposito pulsante.

---

## 6. Schermata Principale e Navigazione

La home dell'app presenta due pulsanti principali ("Leggi Tessera" e "Leggi Anagrafica"), un indicatore di stato connessione/sincronizzazione, il contatore dei record acquisiti nella sessione corrente e un accesso alle impostazioni.

---

## 7. Impostazioni e Configurazione

Le impostazioni includono: URL del foglio Google Sheets di destinazione, identificativo operatore (nome o codice), preferenze fotocamera (risoluzione, flash), timeout scanner barcode, soglia di confidenza OCR sotto la quale evidenziare il campo.

---

## 8. Requisiti Non Funzionali

L'app deve funzionare su Android 8.0 (API 26) e versioni successive. Il riconoscimento barcode deve avvenire in meno di 2 secondi in condizioni normali di luce. L'OCR deve restituire un risultato in meno di 5 secondi. L'app deve funzionare offline per l'acquisizione, con sincronizzazione differita. Tutti i dati in transito verso Google Sheets devono essere cifrati (HTTPS/TLS).

---

## 9. Stack Tecnologico Consigliato (senza Android Studio)

Considerando il vincolo di non usare Android Studio, le opzioni più pratiche sono:

**Flutter via terminale** (VS Code + Flutter CLI) — ottimo supporto per ML Kit, camera, Google Sheets API, sviluppo maturo.

**MIT App Inventor / Kodular** — no-code/low-code, adatto se si vuole prototipare rapidamente, ma con limitazioni sull'OCR avanzato.

**React Native via CLI** — buona alternativa se si ha familiarità con JavaScript/TypeScript.

Per l'OCR su testo manoscritto la soluzione più robusta è **Google Cloud Vision API** (Handwriting recognition), con fallback su **ML Kit on-device** per la modalità offline.

---

## Avanzamento implementazione

| Fase | Stato | Note |
|------|--------|-----|
| **1 – Setup** | ✅ Completata | Progetto Flutter, minSdk 26, cartelle `screens/`, `services/`, `models/`, tema e route. Dipendenze camera/barcode/OCR/Sheets da aggiungere in `pubspec.yaml` quando si implementano le fasi 3–5. |
| **2 – Auth e configurazione** | ⚠️ Parziale | UI Impostazioni (operatore, ID/URL foglio) presente. **Mancano:** OAuth 2.0 Google, persistenza con `shared_preferences`/`flutter_secure_storage`, validazione URL foglio. |
| **3 – Flusso Barcode** | ✅ Implementata | Fotocamera con **mobile_scanner** (scansione continua), feedback vibrazione, conferma FIASP/UMV e coda; fallback inserimento manuale. Sheets in Fase 5. |
| **4 – Flusso OCR** | ✅ Implementata | Fotocamera (**image_picker**) → **ML Kit Text Recognition** → parsing nome/cognome/data → revisione; in errore: Ritenta foto, Inserimento manuale, Annulla. |
| **5 – Consolidamento Sheets** | ⚠️ Parziale | `AcquisitionRecord` e `SyncQueueService` (coda in-memory). **Mancano:** SQLite (`sqflite`) per coda offline, Google Sheets API v4, sync automatica/manuale. |
| **6 – Home e navigazione** | ⚠️ Parziale | Due pulsanti, Impostazioni, indicatore stato (simulato), contatore sessione. **Mancano:** caricamento impostazioni da storage, indicatore reale da `SyncQueueService`, rilevamento connessione. |
| **7 – NFR** | ❌ Non avviata | |
| **8 – Test e APK** | ❌ Non avviata | Script build presenti (`mobile-build-apk.sh`). |

Dopo le integrazioni in corso: persistenza impostazioni, collegamento flussi → coda, Home che legge impostazioni e conteggio coda.

Comandi (Docker-only, dalla root del monorepo):
- `./scripts/mobile-analyze.sh`
- `./scripts/mobile-test.sh`
- `./scripts/mobile-run-web.sh`
- `./scripts/mobile-build-apk.sh`

### Emulatore BlueStacks (da host, non in Docker)

BlueStacks gira sulla **tua macchina** (host). L'ADB deve quindi girare sulla host per connettersi a `localhost:5555`; **non** c'è un comando Docker da lanciare prima per sostituire questo passaggio.

1. **Prerequisito sulla host:** avere `adb` in PATH (Android Studio, oppure `brew install android-platform-tools` su Mac).
2. **Connessione ADB (sempre dalla host, dalla root del monorepo):**
   ```bash
   ./scripts/mobile-adb-connect.sh
   ```
   Oppure a mano: `adb connect localhost:5555` (porta predefinita; se BlueStacks usa un'altra: `./scripts/mobile-adb-connect.sh 5556`). Poi `flutter devices` (sulla host) dovrebbe elencare l'emulatore.
3. **Esecuzione dell'app su BlueStacks:**
   - **Con Flutter in locale:** dalla host, `cd mobile/app && flutter run` e scegli il dispositivo BlueStacks. I comandi Docker non vedono i device della host.
   - **Solo con Docker:** costruisci l'APK con `./scripts/mobile-build-apk.sh` e installalo su BlueStacks (trascina l'APK o `adb install` dalla host).
4. **Fotocamera:** in BlueStacks è virtuale o usa la webcam del PC. Per Leggi Tessera e Leggi Anagrafica concedi i permessi fotocamera all'app (Impostazioni app → Permessi).
