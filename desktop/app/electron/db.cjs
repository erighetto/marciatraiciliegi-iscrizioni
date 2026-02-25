const Database = require('better-sqlite3');
const path = require('node:path');
const fs = require('node:fs');

let db = null;

function getDbPath(userDataPath) {
  return path.join(userDataPath, 'pending.db');
}

function init(userDataPath) {
  if (db) return db;
  const dbPath = getDbPath(userDataPath);
  const dir = path.dirname(dbPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  db = new Database(dbPath);
  db.exec(`
    CREATE TABLE IF NOT EXISTS pending_transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      timestamp TEXT NOT NULL,
      operator_name TEXT NOT NULL,
      station_id TEXT NOT NULL,
      total_participants INTEGER NOT NULL,
      tesserati INTEGER NOT NULL,
      con_dono INTEGER NOT NULL,
      total_amount REAL NOT NULL,
      payment_mode TEXT NOT NULL,
      importo_ricevuto REAL,
      resto REAL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  `);
  return db;
}

function insertPending(record) {
  if (!db) return null;
  const stmt = db.prepare(`
    INSERT INTO pending_transactions (
      timestamp, operator_name, station_id, total_participants, tesserati, con_dono,
      total_amount, payment_mode, importo_ricevuto, resto
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);
  const result = stmt.run(
    record.timestamp,
    record.operatorName,
    record.stationId || '',
    record.totalParticipants,
    record.tesserati,
    record.conDono,
    record.totalAmount,
    record.paymentMode,
    record.importoRicevuto ?? null,
    record.resto ?? null
  );
  return result.lastInsertRowid;
}

function getPendingCount() {
  if (!db) return 0;
  const row = db.prepare('SELECT COUNT(*) AS c FROM pending_transactions').get();
  return row?.c ?? 0;
}

function getAllPending() {
  if (!db) return [];
  return db.prepare(`
    SELECT id, timestamp, operator_name AS operatorName, station_id AS stationId,
           total_participants AS totalParticipants, tesserati, con_dono AS conDono,
           total_amount AS totalAmount, payment_mode AS paymentMode,
           importo_ricevuto AS importoRicevuto, resto, created_at AS createdAt
    FROM pending_transactions ORDER BY created_at ASC
  `).all();
}

function getPendingByOperator(operatorName) {
  if (!db) return [];
  return db.prepare(`
    SELECT id, timestamp, operator_name AS operatorName, station_id AS stationId,
           total_participants AS totalParticipants, tesserati, con_dono AS conDono,
           total_amount AS totalAmount, payment_mode AS paymentMode,
           importo_ricevuto AS importoRicevuto, resto, created_at AS createdAt
    FROM pending_transactions WHERE operator_name = ? ORDER BY created_at ASC
  `).all(operatorName);
}

function deletePending(id) {
  if (!db) return;
  db.prepare('DELETE FROM pending_transactions WHERE id = ?').run(id);
}

function getPendingRow(id) {
  if (!db) return null;
  return db.prepare(`
    SELECT id, timestamp, operator_name AS operatorName, station_id AS stationId,
           total_participants AS totalParticipants, tesserati, con_dono AS conDono,
           total_amount AS totalAmount, payment_mode AS paymentMode,
           importo_ricevuto AS importoRicevuto, resto
    FROM pending_transactions WHERE id = ?
  `).get(id);
}

module.exports = {
  init,
  insertPending,
  getPendingCount,
  getAllPending,
  getPendingByOperator,
  deletePending,
  getPendingRow,
};
