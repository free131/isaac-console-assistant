from pathlib import Path
import hashlib,json,zipfile,tempfile,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
MOD=ROOT/'mod/isaac_console_panel'
files=sorted(p for p in MOD.rglob('*') if p.is_file())
assert all(not p.name.startswith('save') and p.suffix!='.dat' for p in files)
release=ROOT/'release';release.mkdir(exist_ok=True)
target=release/'以撒游戏内指令面板-0.1.0.zip'
with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as z:
    for p in files: z.write(p,'isaac_console_panel/'+p.relative_to(MOD).as_posix())
manifest={p.relative_to(MOD).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
(release/'isaac_console_panel-0.1.0-manifest.json').write_text(json.dumps(manifest,indent=2),'utf-8')
with zipfile.ZipFile(target) as z:
    assert z.testzip() is None
    for name,digest in manifest.items(): assert hashlib.sha256(z.read('isaac_console_panel/'+name)).hexdigest()==digest
    with tempfile.TemporaryDirectory(prefix='mod-unzip-',dir=ROOT/'.cache') as unpack:
        assert Path(unpack).resolve().is_relative_to((ROOT/'.cache').resolve())
        z.extractall(unpack)
        subprocess.run([sys.executable,str(ROOT/'scripts/test_mod.py'),'--mod-path',str(Path(unpack)/'isaac_console_panel')],check=True)
print(str(target))
