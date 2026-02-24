type RuntimeInfo = {
  platform: string
  appVersion: string
}

interface Window {
  desktopBridge?: {
    getRuntimeInfo: () => Promise<RuntimeInfo>
  }
}
