const { app, BrowserWindow, ipcMain, clipboard, dialog } = require('electron');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const { readState, writeState } = require('./state.cjs');
if (process.env.ISAAC_TEST_DATA) app.setPath('userData', process.env.ISAAC_TEST_DATA);
let win, state, recovered = false, stateFile;
const snapshot = () => structuredClone(state);
const result = fn => {
  try { return { ok: true, ...fn() }; }
  catch (err) { return { ok: false, error: err.message || '操作失败，请重试。' }; }
};
function save(next) { writeState(stateFile, next); state = next; return { state: snapshot() }; }
function validCommand(command) { return typeof command === 'string' && command.trim().length > 0 && command.length <= 4000 && !/[\r\n\0]/.test(command); }
function copyAndRecord(record) {
  clipboard.writeText(record.command);
  if (clipboard.readText() !== record.command) throw new Error('剪贴板写入失败，请手动选择下方命令复制。');
  const next = { ...state, history: [{ ...record, id: randomUUID(), time: new Date().toISOString() }, ...state.history].slice(0, 100) };
  try { return { ...save(next), copied: true }; }
  catch { return { copied: true, state: snapshot(), warning: '命令已复制，但历史记录保存失败。' }; }
}
if (!app.requestSingleInstanceLock()) { app.quit(); }
else {
  app.on('second-instance', () => { if (win) { if (win.isMinimized()) win.restore(); win.show(); win.focus(); } });
  app.whenReady().then(() => {
    stateFile = path.join(app.getPath('userData'), 'state-v1.json');
    try { const loaded = readState(stateFile); state = loaded.state; recovered = loaded.recovered; }
    catch (err) { dialog.showErrorBox('无法读取使用记录', '为保护原记录，程序已停止启动。\n' + err.message); app.quit(); return; }
    const handle = (name, fn) => ipcMain.handle(name, (event, ...args) => {
      if (!win || event.sender !== win.webContents || event.senderFrame !== win.webContents.mainFrame) return { ok: false, error: '来源无效' };
      return result(() => fn(...args));
    });
    handle('state:load', () => ({ state: snapshot(), recovered }));
    handle('state:favorite', key => {
      if (typeof key !== 'string' || key.length > 150) throw new Error('收藏条目无效');
      const favorites = state.favorites.includes(key) ? state.favorites.filter(x => x !== key) : [...state.favorites, key];
      return save({ ...state, favorites });
    });
    handle('command:copy', data => {
      if (!data || !validCommand(data.command) || typeof data.entryKey !== 'string' || data.entryKey.length > 150 || typeof data.label !== 'string' || data.label.length > 300) throw new Error('命令格式无效，请检查参数。');
      return copyAndRecord({ command: data.command.trim(), entryKey: data.entryKey, label: data.label });
    });
    handle('history:copy', id => {
      const record = state.history.find(x => x.id === id);
      if (!record) throw new Error('这条历史记录已经不存在');
      return copyAndRecord({ command: record.command, entryKey: record.entryKey, label: record.label });
    });
    handle('history:delete', id => save({ ...state, history: state.history.filter(x => x.id !== id) }));
    handle('history:clear', () => save({ ...state, history: [] }));
    handle('window:on-top', value => {
      if (typeof value !== 'boolean') throw new Error('置顶状态无效');
      const saved = save({ ...state, alwaysOnTop: value }); win.setAlwaysOnTop(value); return saved;
    });
    win = new BrowserWindow({ width: 1320, height: 860, minWidth: 850, minHeight: 620, backgroundColor: '#f5f6f8', title: '以撒控制台助手', autoHideMenuBar: true, alwaysOnTop: state.alwaysOnTop, webPreferences: { preload: path.join(__dirname, 'preload.cjs'), nodeIntegration: false, contextIsolation: true, sandbox: true, spellcheck: false } });
    win.setMenu(null);
    win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
    win.webContents.on('will-navigate', event => event.preventDefault());
    win.loadFile(path.join(__dirname, '../dist/index.html'));
  });
  app.on('window-all-closed', () => app.quit());
}
