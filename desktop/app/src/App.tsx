import { useEffect, useMemo, useState } from 'react'
import type { FormEvent } from 'react'
import { StoricoView } from './StoricoView'

const TARIFFA_TESSERATI_SENZA_DONO = 2.5
const TARIFFA_TESSERATI_CON_DONO = 4.0
const TARIFFA_NON_TESSERATI_SENZA_DONO = 3.5
const TARIFFA_NON_TESSERATI_CON_DONO = 5.0

type RuntimeInfo = {
  platform: string
  appVersion: string
}

type PaymentMode = 'contanti' | 'digitale'

function parseNum(value: string): number {
  const n = parseInt(value, 10)
  return Number.isNaN(n) ? 0 : Math.max(0, n)
}

function parseDecimal(value: string): number {
  const n = parseFloat(value.replace(',', '.'))
  return Number.isNaN(n) ? 0 : Math.max(0, Math.round(n * 100) / 100)
}

function App() {
  const [operatorName, setOperatorName] = useState('')
  const [sessionOperator, setSessionOperator] = useState<string | null>(null)
  const [runtimeInfo, setRuntimeInfo] = useState<RuntimeInfo | null>(null)
  const [loginError, setLoginError] = useState<string | null>(null)

  // Form iscrizione: quattro gruppi espliciti (tesserato sì/no × con dono sì/no)
  const [tesseratiConDono, setTesseratiConDono] = useState('')
  const [tesseratiSenzaDono, setTesseratiSenzaDono] = useState('')
  const [nonTesseratiConDono, setNonTesseratiConDono] = useState('')
  const [nonTesseratiSenzaDono, setNonTesseratiSenzaDono] = useState('')

  // Pagamento (Fase 4)
  const [paymentMode, setPaymentMode] = useState<PaymentMode>('contanti')
  const [importoRicevuto, setImportoRicevuto] = useState('')

  useEffect(() => {
    if (!window.desktopBridge?.getRuntimeInfo) {
      return
    }

    window.desktopBridge
      .getRuntimeInfo()
      .then((info: RuntimeInfo) => setRuntimeInfo(info))
      .catch(() => setRuntimeInfo(null))
  }, [])

  const sessionSubtitle = useMemo(() => {
    if (!runtimeInfo) {
      return 'Modalita sviluppo web'
    }

    return `Postazione ${runtimeInfo.platform} - app v${runtimeInfo.appVersion}`
  }, [runtimeInfo])

  const a = parseNum(tesseratiConDono)
  const b = parseNum(tesseratiSenzaDono)
  const c = parseNum(nonTesseratiConDono)
  const d = parseNum(nonTesseratiSenzaDono)
  const tot = a + b + c + d

  const subtotaleTesseratiSenzaDono = b * TARIFFA_TESSERATI_SENZA_DONO
  const subtotaleTesseratiConDono = a * TARIFFA_TESSERATI_CON_DONO
  const subtotaleNonTesseratiSenzaDono = d * TARIFFA_NON_TESSERATI_SENZA_DONO
  const subtotaleNonTesseratiConDono = c * TARIFFA_NON_TESSERATI_CON_DONO
  const totaleDovuto =
    subtotaleTesseratiSenzaDono +
    subtotaleTesseratiConDono +
    subtotaleNonTesseratiSenzaDono +
    subtotaleNonTesseratiConDono

  const importoRicevutoNum = parseDecimal(importoRicevuto)
  const resto = paymentMode === 'contanti' ? Math.max(0, importoRicevutoNum - totaleDovuto) : 0
  const pagamentoContantiOk = paymentMode !== 'contanti' || importoRicevutoNum >= totaleDovuto

  const formValid = tot > 0 && a >= 0 && b >= 0 && c >= 0 && d >= 0
  const canConsolidate = formValid && pagamentoContantiOk

  const handleLogin = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    const trimmedName = operatorName.trim()

    if (!trimmedName) {
      setLoginError('Inserisci il nominativo operatore per continuare.')
      return
    }

    setSessionOperator(trimmedName)
    setOperatorName('')
    setLoginError(null)
  }

  const handleLogout = () => {
    setSessionOperator(null)
    setLoginError(null)
  }

  const handleConsolidate = async () => {
    if (!canConsolidate || !sessionOperator) return
    const stationId = (await window.desktopBridge?.getStationId?.()) ?? ''
    const payload = {
      timestamp: new Date().toISOString(),
      operatorName: sessionOperator,
      stationId,
      totalParticipants: tot,
      tesseratiConDono: a,
      tesseratiSenzaDono: b,
      nonTesseratiConDono: c,
      nonTesseratiSenzaDono: d,
      totalAmount: Math.round(totaleDovuto * 100) / 100,
      paymentMode,
      importoRicevuto: paymentMode === 'contanti' ? importoRicevutoNum : undefined,
      resto: paymentMode === 'contanti' ? Math.round(resto * 100) / 100 : undefined,
    }
    if (window.desktopBridge?.googleAppendRow) {
      setConsolidateMessage(null)
      try {
        const result = await window.desktopBridge.googleAppendRow(payload)
        if (result?.queued) {
          refreshPendingCount()
          setConsolidateMessage('Transazione salvata in coda; verrà inviata al foglio quando la connessione è disponibile.')
        } else {
          setConsolidateMessage(null)
          setTesseratiConDono('')
          setTesseratiSenzaDono('')
          setNonTesseratiConDono('')
          setNonTesseratiSenzaDono('')
          setImportoRicevuto('')
        }
      } catch (err) {
        refreshPendingCount()
        setConsolidateMessage('Errore durante l\'invio. La transazione è stata messa in coda e verrà sincronizzata quando possibile.')
      }
    } else {
      setConsolidateMessage(
        'Per salvare su Google Sheets avvia l\'app con Electron: dalla root del progetto usa FULL_ELECTRON=1 ./scripts/desktop-dev.sh'
      )
    }
  }


  const refreshPendingCount = () => {
    if (window.desktopBridge?.getPendingCount) {
      window.desktopBridge.getPendingCount().then((n: number) => setPendingCount(n))
    }
  }

  const [pendingCount, setPendingCount] = useState(0)
  const [hasGoogleAuth, setHasGoogleAuth] = useState(false)
  const [view, setView] = useState<'sportello' | 'storico'>('sportello')
  const [consolidateMessage, setConsolidateMessage] = useState<string | null>(null)

  useEffect(() => {
    if (!sessionOperator) return
    refreshPendingCount()
    window.desktopBridge?.googleHasTokens?.().then((v: boolean) => setHasGoogleAuth(!!v)).catch(() => setHasGoogleAuth(false))
    const t = setInterval(refreshPendingCount, 10000)
    return () => clearInterval(t)
  }, [sessionOperator])

  const handleConnectGoogle = () => {
    window.desktopBridge?.googleAuthOpenWindow?.().then((result: { success?: boolean }) => {
      if (result?.success) setHasGoogleAuth(true)
    })
  }

  if (!sessionOperator) {
    return (
      <main className="layout">
        <section className="panel login-panel">
          <h1>Marcia tra i ciliegi</h1>
          <p className="subtitle">Accesso operatore sportello iscrizioni</p>
          <form onSubmit={handleLogin} className="form-stack">
            <label htmlFor="operatorName">Nominativo operatore</label>
            <input
              id="operatorName"
              autoFocus
              value={operatorName}
              onChange={(event) => setOperatorName(event.target.value)}
              placeholder="Nome e cognome o codice operatore"
            />
            {loginError ? <p className="error-text">{loginError}</p> : null}
            <button type="submit">Accedi</button>
          </form>
        </section>
      </main>
    )
  }

  if (view === 'storico' && sessionOperator) {
    return (
      <main className="layout">
        <section className="panel dashboard-panel">
          <header className="panel-header">
            <div>
              <h1>Sportello iscrizioni</h1>
              <p className="subtitle">{sessionSubtitle}</p>
            </div>
            <button type="button" className="ghost-button" onClick={handleLogout}>
              Logout
            </button>
          </header>
          <StoricoView sessionOperator={sessionOperator} onBack={() => setView('sportello')} />
        </section>
      </main>
    )
  }

  return (
    <main className="layout">
      <section className="panel dashboard-panel">
        <header className="panel-header">
          <div>
            <h1>Sportello iscrizioni</h1>
            <p className="subtitle">{sessionSubtitle}</p>
            {pendingCount > 0 ? (
              <p className="pending-badge">{pendingCount} in coda</p>
            ) : null}
          </div>
          <div className="header-actions">
            <button
              type="button"
              className="ghost-button"
              onClick={() => setView('storico')}
            >
              Le mie transazioni
            </button>
            <button type="button" className="ghost-button" onClick={handleLogout}>
              Logout
            </button>
          </div>
        </header>

        {!hasGoogleAuth && window.desktopBridge?.googleAuthOpenWindow ? (
          <div className="google-auth-banner">
            <p>Collega l’account Google per salvare le iscrizioni sul foglio condiviso.</p>
            <button type="button" onClick={handleConnectGoogle}>
              Collega account Google
            </button>
          </div>
        ) : null}

        <div className="registration-form">
          <h2 className="form-title">Nuova iscrizione</h2>
          <form
            className="form-stack"
            onSubmit={(e) => {
              e.preventDefault()
              handleConsolidate()
            }}
          >
            <div className="form-row">
              <label htmlFor="tesseratiConDono">Tesserati FIASP/UMV con dono promozionale</label>
              <input
                id="tesseratiConDono"
                type="number"
                min={0}
                value={tesseratiConDono}
                onChange={(e) => setTesseratiConDono(e.target.value)}
              />
            </div>
            <div className="form-row">
              <label htmlFor="tesseratiSenzaDono">Tesserati FIASP/UMV senza dono</label>
              <input
                id="tesseratiSenzaDono"
                type="number"
                min={0}
                value={tesseratiSenzaDono}
                onChange={(e) => setTesseratiSenzaDono(e.target.value)}
              />
            </div>
            <div className="form-row">
              <label htmlFor="nonTesseratiConDono">Non tesserati con dono promozionale</label>
              <input
                id="nonTesseratiConDono"
                type="number"
                min={0}
                value={nonTesseratiConDono}
                onChange={(e) => setNonTesseratiConDono(e.target.value)}
              />
            </div>
            <div className="form-row">
              <label htmlFor="nonTesseratiSenzaDono">Non tesserati senza dono</label>
              <input
                id="nonTesseratiSenzaDono"
                type="number"
                min={0}
                value={nonTesseratiSenzaDono}
                onChange={(e) => setNonTesseratiSenzaDono(e.target.value)}
              />
            </div>
            <div className="form-row read-only">
              <span className="label">Totale partecipanti</span>
              <span className="value">{tot}</span>
            </div>
            <div className="totals-box">
              <div className="totals-grid">
                <span className="totals-label">Tesserati con dono</span>
                <span className="totals-value">
                  {a} × € {TARIFFA_TESSERATI_CON_DONO.toFixed(2)} = €{' '}
                  {subtotaleTesseratiConDono.toFixed(2)}
                </span>
                <span className="totals-label">Tesserati senza dono</span>
                <span className="totals-value">
                  {b} × € {TARIFFA_TESSERATI_SENZA_DONO.toFixed(2)} = €{' '}
                  {subtotaleTesseratiSenzaDono.toFixed(2)}
                </span>
                <span className="totals-label">Non tesserati con dono</span>
                <span className="totals-value">
                  {c} × € {TARIFFA_NON_TESSERATI_CON_DONO.toFixed(2)} = €{' '}
                  {subtotaleNonTesseratiConDono.toFixed(2)}
                </span>
                <span className="totals-label">Non tesserati senza dono</span>
                <span className="totals-value">
                  {d} × € {TARIFFA_NON_TESSERATI_SENZA_DONO.toFixed(2)} = €{' '}
                  {subtotaleNonTesseratiSenzaDono.toFixed(2)}
                </span>
              </div>
              <p className="total-due">
                Totale dovuto: <strong>€ {totaleDovuto.toFixed(2)}</strong>
              </p>
            </div>

            <fieldset className="payment-fieldset">
              <legend>Modalità pagamento</legend>
              <div className="payment-options">
                <label className="radio-label">
                  <input
                    type="radio"
                    name="paymentMode"
                    checked={paymentMode === 'contanti'}
                    onChange={() => setPaymentMode('contanti')}
                  />
                  Contanti
                </label>
                <label className="radio-label">
                  <input
                    type="radio"
                    name="paymentMode"
                    checked={paymentMode === 'digitale'}
                    onChange={() => setPaymentMode('digitale')}
                  />
                  Digitale (POS / bonifico / altro)
                </label>
              </div>
              {paymentMode === 'contanti' && (
                <div className="form-row">
                  <label htmlFor="importoRicevuto">Importo ricevuto (€)</label>
                  <input
                    id="importoRicevuto"
                    type="text"
                    inputMode="decimal"
                    value={importoRicevuto}
                    onChange={(e) => setImportoRicevuto(e.target.value)}
                    placeholder="0,00"
                  />
                  <p className="resto-line">
                    Resto: <strong>€ {resto.toFixed(2)}</strong>
                  </p>
                  {totaleDovuto > 0 && importoRicevutoNum > 0 && !pagamentoContantiOk ? (
                    <p className="error-text">Importo ricevuto insufficiente.</p>
                  ) : null}
                </div>
              )}
            </fieldset>

            <button type="submit" className="consolidate-button" disabled={!canConsolidate}>
              Consolida
            </button>
            {consolidateMessage ? (
              <p className="consolidate-message" role="alert">
                {consolidateMessage}
              </p>
            ) : null}
          </form>
        </div>
      </section>
    </main>
  )
}

export default App
