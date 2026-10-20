"""Disable unchanged Szx files and restore the verified panel backup; no rebinding."""
from pathlib import Path
import datetime,hashlib,json,shutil,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
report=json.loads((ROOT/'test-artifacts/szx-install.json').read_text('utf-8'))
szx=Path(report['installed']).resolve();mods=szx.parent;game=mods.parent
old=Path(report['disabled_backup']).resolve();target=mods/'isaac_console_panel'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def files(root):return {p.relative_to(root).as_posix():sha(p) for p in root.rglob('*') if p.is_file()}
assert szx.name=='szx_chinese_console' and mods.name=='mods' and (game/'isaac-ng.exe').is_file()
assert not szx.is_symlink() and szx.parent==mods and not target.exists()
assert old.is_relative_to(ROOT/'test-artifacts/disabled-mods') and not old.is_symlink()
assert ET.parse(szx/'metadata.xml').getroot().findtext('id')=='3001774454'
assert ET.parse(old/'metadata.xml').getroot().findtext('id')=='isaac_console_panel'
assert files(szx)==report['files_sha256'],'三只熊文件已变化，拒绝移动'
assert files(old)==files(ROOT/'mod/isaac_console_panel'),'面板备份与仓库版本不一致'
dest=(ROOT/'test-artifacts/disabled-mods'/datetime.datetime.now().strftime('%Y%m%d-%H%M%S')/'szx_chinese_console').resolve()
assert dest.is_relative_to(ROOT/'test-artifacts') and not dest.exists()
save=Path('C:/Users/25937/Documents/My Games/Binding of Isaac Repentance')
settings={p:sha(p) for p in (save/'options.ini',save/'inputconfigs.dat')}
expected=files(old);dest.parent.mkdir(parents=True,exist_ok=True)
# Explicit checked absolute paths, all moves stay in the named game/project folders.
assert szx.resolve().parent==mods and old.is_relative_to(ROOT.resolve())
shutil.move(str(szx),str(dest))
try:shutil.move(str(old),str(target))
except Exception:
    assert dest.is_relative_to(ROOT.resolve()) and not szx.exists()
    shutil.move(str(dest),str(szx));raise
assert files(target)==expected and not szx.exists()
assert all(sha(p)==value for p,value in settings.items())
result={'enabled':str(target),'disabled':str(szx),'disabled_backup':str(dest),
        'settings_unchanged':True,'files_verified':True,'game_verified':False}
(ROOT/'test-artifacts/restore-panel.json').write_bytes(json.dumps(result,ensure_ascii=False,indent=2).encode())
print(json.dumps(result,ensure_ascii=False))
