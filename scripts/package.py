"""白名单打包；不包含依赖缓存、测试记录或本机游戏文件。"""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib
import json
import shutil

root = Path(__file__).resolve().parents[1]
release = root / 'release'
runtime = release / 'win-unpacked'
version = json.loads((root/'package.json').read_text(encoding='utf-8'))['version']
assert (runtime/'IsaacConsoleAssistant.exe').is_file(), '请先构建 Windows 桌面目录'
assert (runtime/'resources/app.asar').is_file(), '缺少应用代码包'

for name in ['README.md','THIRD-PARTY-NOTICES.md','验证报告.md']:
    shutil.copy2(root/name, runtime/name)
shutil.copytree(root/'licenses', runtime/'licenses', dirs_exist_ok=True)
shutil.copy2(root/'node_modules/pinyin-pro/LICENSE',runtime/'licenses/pinyin-pro-LICENSE')
shutil.copy2(root/'node_modules/pinyin-pro/LICENSE',root/'licenses/pinyin-pro-LICENSE')

def zip_files(file, base, files, top):
    with ZipFile(file,'w',ZIP_DEFLATED,compresslevel=6) as archive:
        for f in sorted(files):
            if f.is_file(): archive.write(f, str(Path(top)/f.relative_to(base)))
    with ZipFile(file) as archive:
        error=archive.testzip()
        assert error is None, 'ZIP 校验失败：'+str(error)

binary_zip = release/f'以撒控制台助手-{version}-Windows-x64.zip'
zip_files(binary_zip,runtime,list(runtime.rglob('*')),'以撒控制台助手')
dirs=['src','electron','scripts','tests','licenses']
files=[root/x for x in ['package.json','package-lock.json','tsconfig.json','vite.config.ts','index.html','.gitignore','README.md','THIRD-PARTY-NOTICES.md','验证报告.md']]
for folder in dirs: files.extend((root/folder).rglob('*'))
files=[f for f in files if '__pycache__' not in f.parts and f.suffix!='.pyc']
source_zip=release/f'以撒控制台助手-{version}-源码.zip'
zip_files(source_zip,root,files,'以撒控制台助手源码')
sums=[]
for f in [binary_zip,source_zip]:
    sha=hashlib.sha256(f.read_bytes()).hexdigest()
    sums.append(sha+'  '+f.name)
    print(f.name+': '+str(round(f.stat().st_size/1024/1024,2))+' MiB')
(release/'SHA256SUMS.txt').write_text('\n'.join(sums)+'\n',encoding='utf-8')
print('ZIP integrity verified')
