const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('desktopBridge', {
  getRuntimeInfo: () => ipcRenderer.invoke('app:get-runtime-info'),
  getStationId: () => ipcRenderer.invoke('app:get-station-id'),
  googleHasTokens: () => ipcRenderer.invoke('google:has-tokens'),
  googleAuthGetUrl: () => ipcRenderer.invoke('google:auth-get-url'),
  googleAuthExchangeCode: (code) => ipcRenderer.invoke('google:auth-exchange-code', code),
  googleAuthOpenWindow: () => ipcRenderer.invoke('google:auth-open-window'),
  googleAppendRow: (payload) => ipcRenderer.invoke('google:append-row', payload),
  getPendingCount: () => ipcRenderer.invoke('pending:count'),
  getPendingList: (operatorName) => ipcRenderer.invoke('pending:list', operatorName),
  sheetsReadRange: () => ipcRenderer.invoke('sheets:read-range'),
});
