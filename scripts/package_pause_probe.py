from pathlib import Path
import argparse,datetime,hashlib,json,shutil,subprocess,sys,zipfile,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1];SOURCE=ROOT/'mod/isaac_console_pause_probe'
parser=argparse.ArgumentParser();parser.add_argument('--game',type=Path);args=parser.parse_args()
subprocess.run([sys.executable,str(ROOT/'scripts/test_pause_probe.py')],check=True)
release=ROOT/'release';release.mkdir(exist_ok=True)
target_zip=release/'原版控制台暂停探针.zip'
manifest={p.relative_to(SOURCE).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCE.rglob('*') if p.is_file()}
with zipfile.ZipFile(target_zip,'w',zipfile.ZIP_DEFLATED) as z:
    for name in manifest: z.write(SOURCE/name,'isaac_console_pause_probe/'+name)
with zipfile.ZipFile(target_zip) as z:
    assert z.testzip() is None
    for name,digest in manifest.items(): assert hashlib.sha256(z.read('isaac_console_pause_probe/'+name)).hexdigest()==digest
print(str(target_zip))
if args.game:
    game=args.game.resolve();mods=(game/'mods').resolve();target=mods/'isaac_console_pause_probe'
    assert (game/'isaac-ng.exe').is_file() and mods.is_dir() and mods.parent==game
    assert not target.is_symlink() and target.resolve().parent==mods
    backup=None
    if target.exists():
        assert ET.parse(target/'metadata.xml').getroot().findtext('id')=='isaac_console_pause_probe'
        backups=(ROOT/'test-artifacts/pause-probe-backups').resolve();backups.mkdir(parents=True,exist_ok=True)
        backup=backups/datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
        assert backups.is_relative_to(ROOT.resolve()) and backup.resolve().parent==backups and target.resolve().parent==mods
        shutil.move(str(target),str(backup))
    assert not target.exists() and target.resolve().parent==mods
    shutil.copytree(SOURCE,target)
    actual={p.relative_to(target).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in target.rglob('*') if p.is_file()}
    assert actual==manifest
    report={'path':str(target),'backup':str(backup) if backup else None,'files':len(actual),'hashes_match':True,'main_panel_modified':False,'game_launched':False}
    (ROOT/'test-artifacts/pause-probe-install.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),'utf-8')
    print(json.dumps(report,ensure_ascii=False))
