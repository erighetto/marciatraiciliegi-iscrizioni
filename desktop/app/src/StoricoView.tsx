import { useEffect, useState, useMemo } from 'react'
import { jsPDF } from 'jspdf'
import autoTable from 'jspdf-autotable'

type TransactionRow = {
  timestamp: string
  operatorName: string
  totalParticipants: number | string
  totalAmount: number | string
  paymentMode: string
  synced: boolean
}

function formatDate(ts: string): string {
  try {
    const d = new Date(ts)
    return Number.isNaN(d.getTime()) ? ts : d.toLocaleString('it-IT')
  } catch {
    return ts
  }
}

function downloadCsv(rows: TransactionRow[]) {
  const headers = ['Data/ora', 'Partecipanti', 'Importo (€)', 'Modalità', 'Stato']
  const lines = [
    headers.join(';'),
    ...rows.map((r) =>
      [
        formatDate(r.timestamp),
        String(r.totalParticipants),
        String(r.totalAmount),
        r.paymentMode,
        r.synced ? 'Sincronizzato' : 'In coda',
      ].join(';')
    ),
  ]
  const csv = lines.join('\n')
  const blob = new Blob(['\ufeff' + csv], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `transazioni_${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

function downloadPdf(rows: TransactionRow[]) {
  const doc = new jsPDF({ orientation: 'landscape' })
  doc.setFontSize(14)
  doc.text('Le mie transazioni', 14, 16)
  const tableData = rows.map((r) => [
    formatDate(r.timestamp),
    String(r.totalParticipants),
    String(r.totalAmount),
    r.paymentMode,
    r.synced ? 'Sincronizzato' : 'In coda',
  ])
  autoTable(doc, {
    head: [['Data/ora', 'Partecipanti', 'Importo (€)', 'Modalità', 'Stato']],
    body: tableData,
    startY: 22,
  })
  doc.save(`transazioni_${new Date().toISOString().slice(0, 10)}.pdf`)
}

type Props = {
  sessionOperator: string
  onBack: () => void
}

export function StoricoView({ sessionOperator, onBack }: Props) {
  const [sheetRows, setSheetRows] = useState<TransactionRow[]>([])
  const [pendingRows, setPendingRows] = useState<TransactionRow[]>([])
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    Promise.all([
      window.desktopBridge?.sheetsReadRange?.() ?? Promise.resolve([]),
      window.desktopBridge?.getPendingList?.(sessionOperator) ?? Promise.resolve([]),
    ])
      .then(([sheets, pending]) => {
        if (cancelled) return
        const sheet = (sheets as Array<Record<string, unknown>>).map((r) => ({
          timestamp: String(r.timestamp ?? ''),
          operatorName: String(r.operatorName ?? ''),
          totalParticipants: r.totalParticipants ?? '',
          totalAmount: r.totalAmount ?? '',
          paymentMode: String(r.paymentMode ?? ''),
          synced: true,
        }))
        const pend = (pending as Array<Record<string, unknown>>).map((r) => ({
          timestamp: String(r.timestamp ?? ''),
          operatorName: String(r.operatorName ?? ''),
          totalParticipants: r.totalParticipants ?? '',
          totalAmount: r.totalAmount ?? '',
          paymentMode: String(r.paymentMode ?? ''),
          synced: false,
        }))
        setSheetRows(sheet)
        setPendingRows(pend)
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [sessionOperator])

  const merged = useMemo(() => {
    const all: TransactionRow[] = [...sheetRows, ...pendingRows]
    return all.filter((r) => r.operatorName === sessionOperator)
  }, [sheetRows, pendingRows, sessionOperator])

  const filtered = useMemo(() => {
    if (!dateFrom && !dateTo) return merged
    return merged.filter((r) => {
      const t = new Date(r.timestamp).getTime()
      if (Number.isNaN(t)) return true
      if (dateFrom && t < new Date(dateFrom).setHours(0, 0, 0, 0)) return false
      if (dateTo && t > new Date(dateTo).setHours(23, 59, 59, 999)) return false
      return true
    })
  }, [merged, dateFrom, dateTo])

  return (
    <div className="storico-view">
      <div className="storico-header">
        <button type="button" className="ghost-button" onClick={onBack}>
          Sportello
        </button>
        <h2>Le mie transazioni</h2>
      </div>

      <div className="storico-filters">
        <label>
          Da (data):{' '}
          <input
            type="date"
            value={dateFrom}
            onChange={(e) => setDateFrom(e.target.value)}
          />
        </label>
        <label>
          A (data):{' '}
          <input
            type="date"
            value={dateTo}
            onChange={(e) => setDateTo(e.target.value)}
          />
        </label>
        <div className="storico-export">
          <button
            type="button"
            className="ghost-button"
            onClick={() => downloadCsv(filtered)}
            disabled={filtered.length === 0}
          >
            Esporta CSV
          </button>
          <button
            type="button"
            className="ghost-button"
            onClick={() => downloadPdf(filtered)}
            disabled={filtered.length === 0}
          >
            Esporta PDF
          </button>
        </div>
      </div>

      {loading ? (
        <p className="storico-loading">Caricamento…</p>
      ) : (
        <div className="storico-table-wrap">
          <table className="storico-table">
            <thead>
              <tr>
                <th>Data/ora</th>
                <th>Partecipanti</th>
                <th>Importo (€)</th>
                <th>Modalità</th>
                <th>Stato</th>
              </tr>
            </thead>
            <tbody>
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan={5}>Nessuna transazione nel periodo selezionato.</td>
                </tr>
              ) : (
                filtered.map((r, i) => (
                  <tr key={`${r.timestamp}-${i}`}>
                    <td>{formatDate(r.timestamp)}</td>
                    <td>{r.totalParticipants}</td>
                    <td>{r.totalAmount}</td>
                    <td>{r.paymentMode}</td>
                    <td>{r.synced ? 'Sincronizzato' : 'In coda'}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
