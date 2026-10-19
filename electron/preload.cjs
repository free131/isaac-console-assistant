const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('isaac', Object.freeze({
  loadState: () => ipcRenderer.invoke('state:load'),
  favorite: key => ipcRenderer.invoke('state:favorite', key),
  copy: payload => ipcRenderer.invoke('command:copy', payload),
  copyHistory: id => ipcRenderer.invoke('history:copy', id),
  deleteHistory: id => ipcRenderer.invoke('history:delete', id),
  clearHistory: () => ipcRenderer.invoke('history:clear'),
  setOnTop: value => ipcRenderer.invoke('window:on-top', value)
}));
