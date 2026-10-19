const fs = require('node:fs');
const path = require('node:path');
const emptyState = () => ({ version: 1, favorites: [], history: [], alwaysOnTop: false });
function normalize(raw) {
  if (!raw || raw.version !== 1 || !Array.isArray(raw.favorites) || !Array.isArray(raw.history)) throw new Error('记录格式不正确');
  return {
    version: 1,
    favorites: [...new Set(raw.favorites.filter(x => typeof x === 'string' && x.length < 150))],
    history: raw.history.filter(x => x && typeof x.id === 'string' && typeof x.entryKey === 'string' && typeof x.label === 'string' && typeof x.command === 'string' && x.command.length <= 4000 && !/[\r\n\0]/.test(x.command) && typeof x.time === 'string').slice(0, 100),
    alwaysOnTop: raw.alwaysOnTop === true
  };
}
function readState(file) {
  try { return { state: normalize(JSON.parse(fs.readFileSync(file, 'utf8'))), recovered: false }; }
  catch (err) {
    if (err.code === 'ENOENT') return { state: emptyState(), recovered: false };
    // 保留损坏文件；备份失败时让调用方报告错误，不能覆盖原文件。
    const backup = file + '.corrupt-' + Date.now();
    fs.copyFileSync(file, backup, fs.constants.COPYFILE_EXCL);
    return { state: emptyState(), recovered: true, backup };
  }
}
function writeState(file, state) {
  const safe = normalize(state);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const temp = file + '.tmp';
  fs.writeFileSync(temp, JSON.stringify(safe, null, 2), { encoding: 'utf8', mode: 0o600 });
  fs.renameSync(temp, file);
}
module.exports = { emptyState, normalize, readState, writeState };
