import { useEffect, useMemo, useState } from 'react'
import type { FormEvent } from 'react'

type RuntimeInfo = {
  platform: string
  appVersion: string
}

function App() {
  const [operatorName, setOperatorName] = useState('')
  const [sessionOperator, setSessionOperator] = useState<string | null>(null)
  const [runtimeInfo, setRuntimeInfo] = useState<RuntimeInfo | null>(null)
  const [loginError, setLoginError] = useState<string | null>(null)

  useEffect(() => {
    if (!window.desktopBridge?.getRuntimeInfo) {
      return
    }

    window.desktopBridge
      .getRuntimeInfo()
      .then((info) => setRuntimeInfo(info))
      .catch(() => setRuntimeInfo(null))
  }, [])

  const sessionSubtitle = useMemo(() => {
    if (!runtimeInfo) {
      return 'Modalita sviluppo web'
    }

    return `Postazione ${runtimeInfo.platform} - app v${runtimeInfo.appVersion}`
  }, [runtimeInfo])

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

        <div className="welcome-box">
          <p className="welcome-text">Operatore in sessione: {sessionOperator}</p>
          <p className="hint-text">
            Fase iniziale completata: login/logout e struttura base operativa pronti.
          </p>
        </div>

        <div className="next-steps">
          <h2>Prossimi blocchi di sviluppo</h2>
          <ul>
            <li>Form iscrizione con validazioni e calcolo tariffario real-time.</li>
            <li>Gestione pagamento contanti/digitale e blocco consolidamento.</li>
            <li>Persistenza locale coda offline e sync su Google Sheets.</li>
          </ul>
        </div>
      </section>
    </main>
  )
}

export default App
