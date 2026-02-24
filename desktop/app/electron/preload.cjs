const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('desktopBridge', {
  getRuntimeInfo: () => ipcRenderer.invoke('app:get-runtime-info')
});
