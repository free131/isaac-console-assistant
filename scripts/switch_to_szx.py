"""Install unchanged author files; disable only our verified panel by moving it out."""
from pathlib import Path
import datetime,hashlib,json,shutil,xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
GAME=Path('E:/The.Binding.of.Isaac.and.The.Binding.of.Isaac.Rebirth.Build.10102354').resolve()
SOURCE=ROOT/'.cache/szx-chinese-console/source'
ZIP=ROOT/'.cache/szx-chinese-console/upstream.zip'
ZIP_SHA='8ad47b7d5269f7355e17ece390571a7291c944f6fb8b97d28eaefd6bfbe14167'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def files(root):return {p.relative_to(root).as_posix():sha(p) for p in root.rglob('*') if p.is_file()}

assert sha(ZIP)==ZIP_SHA
mods=(GAME/'mods').resolve();old=mods/'isaac_console_panel';new=mods/'szx_chinese_console'
assert (GAME/'isaac-ng.exe').is_file() and mods.parent==GAME
assert not new.exists(),'目标已存在，拒绝覆盖'
for target in (old,new):assert target.resolve().parent==mods and not target.is_symlink()
assert ET.parse(old/'metadata.xml').getroot().findtext('id')=='isaac_console_panel'
assert files(old)==files(ROOT/'mod/isaac_console_panel'),'旧面板文件与本仓库不一致，拒绝移动'
assert ET.parse(SOURCE/'metadata.xml').getroot().findtext('id')=='3001774454'
expected=files(SOURCE)
backup=(ROOT/'test-artifacts/disabled-mods'/datetime.datetime.now().strftime('%Y%m%d-%H%M%S')/'isaac_console_panel').resolve()
assert backup.is_relative_to((ROOT/'test-artifacts').resolve()) and not backup.exists()
save=Path('C:/Users/25937/Documents/My Games/Binding of Isaac Repentance')
settings={p:sha(p) for p in (save/'options.ini',save/'inputconfigs.dat') if p.is_file()}
exe=sha(GAME/'isaac-ng.exe')
# Prepare and verify the new Mod before disabling the existing panel.
shutil.copytree(SOURCE,new)
assert files(new)==expected
backup.parent.mkdir(parents=True,exist_ok=True)
assert old.resolve().parent==mods and backup.is_relative_to(ROOT.resolve())
try:shutil.move(str(old),str(backup))
except Exception:
    # Keep both complete directories for diagnosis; do not delete user files.
    raise
assert not old.exists() and files(backup)==files(ROOT/'mod/isaac_console_panel')
assert all(sha(p)==value for p,value in settings.items())
assert sha(GAME/'isaac-ng.exe')==exe
report={'disabled_mod':str(old),'disabled_backup':str(backup),'installed':str(new),
        'source':'https://github.com/enthusiasmgame2001/isaac-szx-chinese-console',
        'archive_sha256':ZIP_SHA,'files':len(expected),'hashes_match':True,
        'author_files_modified':False,'settings_unchanged':True,'game_verified':False,
        'optional_dependencies_installed':False,'files_sha256':expected}
(ROOT/'test-artifacts/szx-install.json').write_bytes(json.dumps(report,ensure_ascii=False,indent=2).encode('utf-8'))
print(json.dumps({k:v for k,v in report.items() if k!='files_sha256'},ensure_ascii=False))
