from pathlib import Path
import json,sys,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1];MOD=ROOT/'mod/isaac_console_pause_probe'
sys.path.insert(0,str(ROOT/'.cache/python'))
from lupa.lua53 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().include=lambda name:lua.execute((MOD/(name+'.lua')).read_text('utf-8'))
for file in MOD.glob('*.lua'): lua.execute('assert(load(...))',file.read_text('utf-8'))
groups=lua.execute((ROOT/'tests/pause_probe.lua').read_text('utf-8'))
entry=LuaRuntime(unpack_returned_tuples=True)
entry.globals().include=lambda name:entry.execute((MOD/(name+'.lua')).read_text('utf-8'))
entry.execute((ROOT/'tests/mod_runtime.lua').read_text('utf-8').split("include('main')")[0])
entry.execute('ModCallbacks.MC_POST_UPDATE=8;Keyboard.KEY_F6=295;Keyboard.KEY_F7=296;Keyboard.KEY_GRAVE_ACCENT=96;clock=0;Isaac.GetTime=function() return clock end;Isaac.ConsoleOutput=function(s) output=s end;Game().TimeCounter=0')
entry.execute((MOD/'main.lua').read_text('utf-8'))
entry.execute('callbacks[5]();keys[295]=true;callbacks[1]();keys[295]=false;callbacks[1]();assert(callbacks[2](nil,nil,1,28)==true);assert(callbacks[2](nil,nil,1,28)==nil);clock=2000;callbacks[1]();ICPPauseProbe.Mark("A");ICPPauseProbe.Report();assert(output and saved~="");callbacks[6]();assert(callbacks[2](nil,nil,1,28)==nil)')
ET.parse(MOD/'metadata.xml')
report={'syntax':'Lua 5.3','module_test_groups':groups,'entry_callback_harness_passed':True,'offline_passed':True,'native_console_tested':False}
(ROOT/'test-artifacts/pause-probe-offline.json').write_text(json.dumps(report,indent=2),'utf-8')
print(json.dumps(report))
