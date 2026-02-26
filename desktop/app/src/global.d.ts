declare global {
  type RuntimeInfo = {
    platform: string
    appVersion: string
  }

  type TransactionPayload = {
    timestamp: string
    operatorName: string
    stationId: string
    totalParticipants: number
    tesseratiConDono: number
    tesseratiSenzaDono: number
    nonTesseratiConDono: number
    nonTesseratiSenzaDono: number
    totalAmount: number
    paymentMode: 'contanti' | 'digitale'
    importoRicevuto?: number
    resto?: number
  }

  interface Window {
    desktopBridge?: {
      getRuntimeInfo: () => Promise<RuntimeInfo>
      getStationId?: () => Promise<string>
      googleHasTokens?: () => Promise<boolean>
      googleAuthGetUrl?: () => Promise<string>
      googleAuthExchangeCode?: (code: string) => Promise<{ success: boolean; error?: string }>
      googleAuthOpenWindow?: () => Promise<{ success: boolean; error?: string }>
      googleAppendRow?: (payload: TransactionPayload) => Promise<{ queued?: boolean }>
      getPendingCount?: () => Promise<number>
      getPendingList?: (operatorName?: string) => Promise<Array<Record<string, unknown>>>
      sheetsReadRange?: () => Promise<unknown[]>
    }
  }
}

export {}
