"""Install/roll back the exact official J835 legacy dependency; never run its updater."""
from pathlib import Path,PurePosixPath
import argparse,datetime,hashlib,json,re,shutil,zipfile
ROOT=Path(__file__).resolve().parents[1]
ZIP_SHA='13cb8cd2ef72a5b11dcc67615215386d270f723f68808567db807d40063f5861'
EXE_SHA='530b4d2accef833b8dbf6f1a9f781fe1e051c1916ca5acdb579df05a34640627'
ARCHIVE=ROOT/'.cache/pause-research/REPENTOGON.zip'
BACKUPS=ROOT/'test-artifacts/engine-backups'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def target_path(game,name):
    rel=PurePosixPath(name)
    assert not rel.is_absolute() and '..' not in rel.parts and ':' not in name
    target=game.joinpath(*rel.parts)
    assert not target.is_symlink() and target.resolve().is_relative_to(game)
    return target
def install(game,dry=False):
    game=game.resolve();assert sha(game/'isaac-ng.exe')==EXE_SHA,'仅支持已核对的本机 J835 EXE'
    assert sha(ARCHIVE)==ZIP_SHA,'扩展包与官方 SHA-256 不同'
    with zipfile.ZipFile(ARCHIVE) as z:
        assert z.testzip() is None
        files={i.filename:z.read(i) for i in z.infolist() if not i.is_dir()}
    files['dsound.ini']=b'[Options]\nCheckForUpdates=0\n'
    assert all(not target_path(game,n).exists() for n in files),'目标已有同名原生扩展文件，拒绝覆盖'
    backup=(BACKUPS/datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')).resolve()
    assert backup.is_relative_to(ROOT.resolve())
    report={'game':str(game),'version':'1.0.12e','archive_sha256':ZIP_SHA,'exe_sha256':EXE_SHA,'files':{},'data_backup':[],'dry_run':dry}
    for name,data in files.items():report['files'][name]={'installed_sha256':hashlib.sha256(data).hexdigest(),'original':False}
    save_info=(game/'savedatapath.txt').read_text('utf-8-sig')
    match=re.search(r'^Save Data Path:\s*(.+)$',save_info,re.M);assert match,'找不到真实存档路径'
    save_dir=Path(match[1].strip()).resolve();assert save_dir.is_dir()
    originals=[p for p in save_dir.iterdir() if p.is_file() and p.suffix.lower() in ('.dat','.ini')]
    if dry:
        report['backup_candidate_files']=len(originals);print(json.dumps(report,ensure_ascii=False,indent=2));return
    backup.mkdir(parents=True)
    for p in originals:
        dest=backup/'save-and-config'/p.name;dest.parent.mkdir(exist_ok=True);shutil.copy2(p,dest)
        assert sha(p)==sha(dest)
        report['data_backup'].append({'original':str(p),'backup':str(dest),'sha256':sha(dest)})
    # Save an initial manifest before touching game files, for recoverable partial installs.
    manifest=backup/'manifest.json';manifest.write_text(json.dumps(report,ensure_ascii=False,indent=2),'utf-8')
    for name,data in files.items():
        target=target_path(game,name);assert not target.exists();target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
        assert sha(target)==report['files'][name]['installed_sha256']
    assert sha(game/'isaac-ng.exe')==EXE_SHA
    report['installed']=True;manifest.write_text(json.dumps(report,ensure_ascii=False,indent=2),'utf-8')
    (ROOT/'test-artifacts/engine-install.json').write_text(json.dumps({'manifest':str(manifest),'game':str(game),'version':'1.0.12e','files':len(files),'auto_updates':False,'game_launched':False},ensure_ascii=False,indent=2),'utf-8')
    print(json.dumps({'installed':str(game),'version':'1.0.12e','files':len(files),'save_config_backups':len(originals),'rollback_manifest':str(manifest)},ensure_ascii=False))
def rollback(path):
    path=path.resolve();assert path.is_relative_to(BACKUPS.resolve())
    report=json.loads(path.read_text('utf-8'));game=Path(report['game']).resolve()
    assert sha(game/'isaac-ng.exe')==report['exe_sha256']
    targets=[]
    for name,row in report['files'].items():
        p=target_path(game,name)
        if p.exists():assert p.is_file() and sha(p)==row['installed_sha256'],'文件已变化，拒绝覆盖或删除：'+name;targets.append(p)
    # File-only removal, limited to verified dependency files; no recursive deletes.
    for p in targets:assert p.resolve().is_relative_to(game);p.unlink()
    print(json.dumps({'removed_dependency_files':len(targets),'save_config_backups_retained':True,'note':'User settings/save backups are retained, never silently restored over later progress.'}))
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--game',type=Path);parser.add_argument('--install',action='store_true');parser.add_argument('--rollback',type=Path);args=parser.parse_args()
    if args.rollback:rollback(args.rollback)
    else:assert args.game;install(args.game,dry=not args.install)
