const path = require('node:path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const { app, BrowserWindow, ipcMain, safeStorage } = require('electron');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const crypto = require('node:crypto');

const db = require('./db.cjs');
const { google } = require('googleapis');

const REDIRECT_PORT = 3131;
const SCOPES = ['https://www.googleapis.com/auth/spreadsheets'];
const TOKENS_FILE = 'tokens.enc';
const STATION_FILE = 'station.json';

let authWindow = null;
let oauth2Client = null;
let redirectServer = null;

function getUserDataPath() {
  return app.getPath('userData');
}

function getStationId() {
  const userData = getUserDataPath();
  const stationPath = path.join(userData, STATION_FILE);
  try {
    const data = JSON.parse(fs.readFileSync(stationPath, 'utf8'));
    if (data.stationId) return data.stationId;
  } catch (_) {}
  const stationId = `${os.hostname()}-${crypto.randomBytes(4).toString('hex')}`;
  fs.mkdirSync(userData, { recursive: true });
  fs.writeFileSync(stationPath, JSON.stringify({ stationId }), 'utf8');
  return stationId;
}

function getTokensPath() {
  return path.join(getUserDataPath(), TOKENS_FILE);
}

function loadStoredTokens() {
  const tokensPath = getTokensPath();
  if (!fs.existsSync(tokensPath) || !safeStorage.isEncryptionAvailable()) return null;
  try {
    const encrypted = fs.readFileSync(tokensPath);
    const decrypted = safeStorage.decryptString(encrypted);
    return JSON.parse(decrypted);
  } catch (_) {
    return null;
  }
}

function saveTokens(tokens) {
  if (!safeStorage.isEncryptionAvailable()) return false;
  const tokensPath = getTokensPath();
  fs.mkdirSync(path.dirname(tokensPath), { recursive: true });
  const encrypted = safeStorage.encryptString(JSON.stringify(tokens));
  fs.writeFileSync(tokensPath, encrypted);
  return true;
}

function getOAuth2Client() {
  const clientId = process.env.GOOGLE_CLIENT_ID;
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
  if (!clientId || !clientSecret) return null;
  if (oauth2Client) return oauth2Client;
  const { OAuth2Client } = require('google-auth-library');
  const client = new OAuth2Client(
    clientId,
    clientSecret,
    `http://localhost:${REDIRECT_PORT}/callback`
  );
  const stored = loadStoredTokens();
  if (stored) {
    client.setCredentials(stored);
    client.on('tokens', (tokens) => {
      const existing = loadStoredTokens() || {};
      saveTokens({ ...existing, ...tokens });
    });
  }
  oauth2Client = client;
  return client;
}

function getAuthUrl() {
  const client = getOAuth2Client();
  if (!client) return null;
  return client.generateAuthUrl({
    access_type: 'offline',
    scope: SCOPES,
    prompt: 'consent',
  });
}

function startRedirectServer(onCode) {
  return new Promise((resolve, reject) => {
    if (redirectServer) {
      redirectServer.close();
    }
    redirectServer = http.createServer((req, res) => {
      const url = new URL(req.url || '', `http://localhost:${REDIRECT_PORT}`);
      if (url.pathname === '/callback') {
        const code = url.searchParams.get('code');
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end(
          '<!DOCTYPE html><html><body><p>Autorizzazione completata. Puoi chiudere questa finestra.</p></body></html>'
        );
        if (code) onCode(code);
      }
    });
    redirectServer.listen(REDIRECT_PORT, '127.0.0.1', () => resolve()).on('error', reject);
  });
}

function stopRedirectServer() {
  if (redirectServer) {
    redirectServer.close();
    redirectServer = null;
  }
}

function transactionToRow(payload) {
  return [
    payload.timestamp,
    payload.operatorName,
    payload.stationId || '',
    String(payload.totalParticipants),
    String(payload.tesseratiConDono ?? 0),
    String(payload.tesseratiSenzaDono ?? 0),
    String(payload.nonTesseratiConDono ?? 0),
    String(payload.nonTesseratiSenzaDono ?? 0),
    String(payload.totalAmount),
    payload.paymentMode,
    payload.importoRicevuto != null ? String(payload.importoRicevuto) : '',
    payload.resto != null ? String(payload.resto) : '',
  ];
}

function appendToSheet(payload) {
  const sheetId = process.env.GOOGLE_SHEET_ID;
  const range = process.env.GOOGLE_SHEET_RANGE || 'Foglio1!A:L';
  if (!sheetId) throw new Error('GOOGLE_SHEET_ID non configurato');
  const client = getOAuth2Client();
  if (!client) throw new Error('Google non configurato o non autenticato');
  const sheets = google.sheets({ version: 'v4', auth: client });
  return sheets.spreadsheets.values.append({
    spreadsheetId: sheetId,
    range,
    valueInputOption: 'USER_ENTERED',
    insertDataOption: 'INSERT_ROWS',
    resource: { values: [transactionToRow(payload)] },
  });
}

function createMainWindow() {
  const mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 1024,
    minHeight: 720,
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  const devServerUrl = process.env.VITE_DEV_SERVER_URL;
  if (devServerUrl) {
    mainWindow.loadURL(devServerUrl);
    mainWindow.webContents.openDevTools({ mode: 'detach' });
    return mainWindow;
  }

  mainWindow.loadFile(path.join(__dirname, '..', 'dist', 'index.html'));
  return mainWindow;
}

function syncPendingQueue() {
  const pending = db.getAllPending();
  for (const row of pending) {
    const payload = {
      timestamp: row.timestamp,
      operatorName: row.operatorName,
      stationId: row.stationId,
      totalParticipants: row.totalParticipants,
      tesseratiConDono: row.tesseratiConDono ?? 0,
      tesseratiSenzaDono: row.tesseratiSenzaDono ?? 0,
      nonTesseratiConDono: row.nonTesseratiConDono ?? 0,
      nonTesseratiSenzaDono: row.nonTesseratiSenzaDono ?? 0,
      totalAmount: row.totalAmount,
      paymentMode: row.paymentMode,
      importoRicevuto: row.importoRicevuto,
      resto: row.resto,
    };
    try {
      appendToSheet(payload);
      db.deletePending(row.id);
    } catch (_) {
      // keep in queue, retry later
    }
  }
}

app.whenReady().then(() => {
  db.init(getUserDataPath());

  ipcMain.handle('app:get-runtime-info', () => ({
    platform: process.platform,
    appVersion: app.getVersion(),
  }));

  ipcMain.handle('app:get-station-id', () => getStationId());

  ipcMain.handle('google:has-tokens', () => !!loadStoredTokens());

  ipcMain.handle('google:auth-get-url', async () => {
    const url = getAuthUrl();
    return url || '';
  });

  ipcMain.handle('google:auth-exchange-code', async (_, code) => {
    if (!code || typeof code !== 'string') {
      return { success: false, error: 'Codice mancante' };
    }
    const client = getOAuth2Client();
    if (!client) return { success: false, error: 'OAuth non configurato' };
    try {
      const { tokens } = await client.getToken(code);
      client.setCredentials(tokens);
      if (!saveTokens(tokens)) return { success: false, error: 'Impossibile salvare i token' };
      return { success: true };
    } catch (err) {
      return { success: false, error: err?.message || 'Scambio codice fallito' };
    }
  });

  ipcMain.handle('google:auth-open-window', async () => {
    const url = getAuthUrl();
    if (!url) return { success: false, error: 'GOOGLE_CLIENT_ID e GOOGLE_CLIENT_SECRET non configurati' };
    let resolveAuth;
    let settled = false;
    const authPromise = new Promise((resolve) => {
      resolveAuth = (result) => {
        if (settled) return;
        settled = true;
        resolve(result);
      };
    });
    await startRedirectServer((code) => {
      (async () => {
        try {
          const client = getOAuth2Client();
          const { tokens } = await client.getToken(code);
          client.setCredentials(tokens);
          if (!saveTokens(tokens)) {
            resolveAuth({ success: false, error: 'Impossibile salvare i token' });
          } else {
            resolveAuth({ success: true });
          }
        } catch (err) {
          resolveAuth({ success: false, error: err?.message || 'Autorizzazione fallita' });
        } finally {
          if (authWindow && !authWindow.isDestroyed()) authWindow.close();
          stopRedirectServer();
        }
      })();
    });
    authWindow = new BrowserWindow({
      width: 520,
      height: 700,
      webPreferences: { nodeIntegration: false },
    });
    authWindow.loadURL(url);
    authWindow.on('closed', () => {
      stopRedirectServer();
      resolveAuth({ success: false, error: 'Finestra chiusa' });
      authWindow = null;
    });
    return authPromise;
  });

  ipcMain.handle('google:append-row', async (_, payload) => {
    try {
      await appendToSheet(payload);
      return {};
    } catch (err) {
      try {
        db.insertPending(payload);
        return { queued: true };
      } catch (_) {
        throw err;
      }
    }
  });

  ipcMain.handle('pending:count', () => db.getPendingCount());

  ipcMain.handle('pending:list', (_, operatorName) => {
    if (operatorName) return db.getPendingByOperator(operatorName);
    return db.getAllPending();
  });

  const SHEET_KEYS = [
    'timestamp',
    'operatorName',
    'stationId',
    'totalParticipants',
    'tesseratiConDono',
    'tesseratiSenzaDono',
    'nonTesseratiConDono',
    'nonTesseratiSenzaDono',
    'totalAmount',
    'paymentMode',
    'importoRicevuto',
    'resto',
  ];

  ipcMain.handle('sheets:read-range', async () => {
    const sheetId = process.env.GOOGLE_SHEET_ID;
    const range = process.env.GOOGLE_SHEET_RANGE || 'Foglio1!A:L';
    if (!sheetId) return [];
    const client = getOAuth2Client();
    if (!client) return [];
    try {
      const sheets = google.sheets({ version: 'v4', auth: client });
      const res = await sheets.spreadsheets.values.get({ spreadsheetId: sheetId, range });
      const rows = res.data.values || [];
      return rows.map((row) => {
        const obj = { synced: true };
        SHEET_KEYS.forEach((key, i) => {
          obj[key] = row[i] ?? '';
        });
        return obj;
      });
    } catch (_) {
      return [];
    }
  });

  setInterval(syncPendingQueue, 30000);
  syncPendingQueue();

  createMainWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createMainWindow();
    }
  });
});

app.on('window-all-closed', () => {
  stopRedirectServer();
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
