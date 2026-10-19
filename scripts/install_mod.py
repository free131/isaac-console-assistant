"""Install only this independent Mod. Run after mod:package, with the game closed."""
from pathlib import Path
import argparse,datetime,hashlib,json,shutil,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--game',type=Path,required=True);args=parser.parse_args()
game=args.game.resolve();mods=(game/'mods').resolve();target=mods/'isaac_console_panel'
source=(ROOT/'mod/isaac_console_panel').resolve()
assert (game/'isaac-ng.exe').is_file() and mods.is_dir(),'游戏目录不正确'
assert mods.parent==game and not target.is_symlink() and target.resolve().parent==mods,'目标路径异常，拒绝安装'
expected=json.loads((ROOT/'release/isaac_console_panel-0.1.0-manifest.json').read_text('utf-8'))
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
actual={p.relative_to(source).as_posix():digest(p) for p in source.rglob('*') if p.is_file()}
assert actual==expected,'源码与已测试发布清单不同，请先重新打包'
stamp=datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
report_dir=ROOT/'test-artifacts';report_dir.mkdir(exist_ok=True)
backup=None
if target.exists():
    assert target.is_dir() and ET.parse(target/'metadata.xml').getroot().findtext('id')=='isaac_console_panel','同名目录不属于本 Mod，拒绝覆盖'
    backups=(report_dir/'mod-backups').resolve();backups.mkdir(exist_ok=True)
    backup=backups/stamp
    assert backup.resolve().parent==backups and backups.is_relative_to(ROOT.resolve()) and target.resolve().parent==mods
    print('备份已核对的旧 Mod: '+str(target)+' -> '+str(backup))
    shutil.move(str(target),str(backup))
assert target.resolve().parent==mods and not target.exists()
shutil.copytree(source,target)
installed={p.relative_to(target).as_posix():digest(p) for p in target.rglob('*') if p.is_file()}
assert installed==expected,'安装后文件校验失败，旧版本已保留在备份路径'
report={'installed':str(target),'version':'0.1.0','files':len(installed),'hashes_match':True,'backup':str(backup) if backup else None,'game_launched':False,'game_commands_executed':False,'files_sha256':installed}
(report_dir/'mod-install.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),'utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='files_sha256'},ensure_ascii=False))
