from pathlib import Path
import json,sys,struct,xml.etree.ElementTree as ET,argparse,re
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--mod-path',type=Path,default=ROOT/'mod/isaac_console_panel');args=parser.parse_args();MOD=args.mod_path
sys.path.insert(0,str(ROOT/'.cache/python'))
from PIL import Image
from lupa.lua53 import LuaRuntime,lua_type
def runtime():
    lua=LuaRuntime(unpack_returned_tuples=True)
    def include(name): return lua.execute((MOD/(name.replace('.','/')+'.lua')).read_text('utf-8'))
    lua.globals().include=include
    return lua
syntax=[]
lua=runtime()
catalog=lua.execute((MOD/'icp/catalog.lua').read_text('utf-8'))
reference=json.loads((ROOT/'src/data/enum-reference.json').read_text('utf-8'))
for name,category,prefix in [('CollectibleType','collectibles','COLLECTIBLE_'),('TrinketType','trinkets','TRINKET_'),('Card','cards',''),('PillEffect','pills','PILLEFFECT_')]:
    expected={value for symbol,value in reference[name].items() if (symbol.startswith(prefix) if prefix else symbol.startswith(('CARD_','RUNE_'))) and value>=(0 if category=='pills' else 1) and not re.search('OBSOLETE|_NULL|_FLAG|_MASK',symbol)}
    actual={e.id for e in catalog.entries.values() if e.category==category}
    assert actual==expected,(category,actual^expected)
for p in MOD.rglob('*.lua'):
    lua.execute('assert(load(...))',p.read_text('utf-8'));syntax.append(str(p.relative_to(MOD)))
suite=lua.execute((ROOT/'tests/mod_spec.lua').read_text('utf-8'))
def to_python(value):
    if lua_type(value)!='table': return value
    keys=list(value.keys())
    if keys and all(isinstance(k,int) for k in keys) and set(keys)==set(range(1,len(keys)+1)):
        return [to_python(value[i]) for i in range(1,len(keys)+1)]
    return {str(k):to_python(value[k]) for k in keys}
def attach_json(lua):
    def to_lua(value):
        if isinstance(value,dict): return lua.table_from({k:to_lua(v) for k,v in value.items()})
        if isinstance(value,list): return lua.table_from([to_lua(v) for v in value])
        return value
    lua.globals().json_bridge=lua.table_from({'encode':lambda t:json.dumps(to_python(t),ensure_ascii=False),'decode':lambda s:to_lua(json.loads(s))})
runtime_source=(ROOT/'tests/mod_runtime.lua').read_text('utf-8')
runtime_lua=runtime();attach_json(runtime_lua);runtime_groups=runtime_lua.execute(runtime_source)
navigation_lua=runtime();attach_json(navigation_lua);navigation_lua.execute(runtime_source)
navigation_groups=navigation_lua.execute((ROOT/'tests/mod_navigation.lua').read_text('utf-8'))
keyboard_lua=runtime();attach_json(keyboard_lua);keyboard_lua.execute(runtime_source)
keyboard_groups=keyboard_lua.execute((ROOT/'tests/mod_keyboard.lua').read_text('utf-8'))
back_lua=runtime();attach_json(back_lua);back_lua.execute(runtime_source)
back_groups=back_lua.execute((ROOT/'tests/mod_back_render.lua').read_text('utf-8'))
runtime_lua.execute('keys[292]=true;callbacks[1]();keys[292]=false;callbacks[1]()')
runtime_lua.execute('keys[341]=true;keys[75]=true;callbacks[1]();keys[341]=false;keys[75]=false;callbacks[1]()')
for c in 'FEIXING': runtime_lua.execute('keys[...]=true;callbacks[1]();keys[...]=false;callbacks[1]()',ord(c),ord(c))
runtime_lua.execute('keys[257]=true;callbacks[1]();keys[257]=false;callbacks[1]();callbacks[6]()')
persisted=runtime_lua.globals().saved
restored=json.loads(persisted)
assert restored['run']['flight'] and restored['favorites']['resource:coins'] and len(restored['history'])>=2
def restart(raw,continued):
    vm=runtime();attach_json(vm);vm.globals().initialSave=raw
    vm.execute(runtime_source.split("include('main')")[0]);vm.execute("include('main')")
    vm.execute('callbacks[5](nil,...);callbacks[3](nil,runtime_player,128)',continued)
    return vm
assert restart(persisted,True).globals().runtime_player.CanFly is True
assert restart(persisted,False).globals().runtime_player.CanFly is None
corrupt=restart('broken original JSON',True)
assert json.loads(corrupt.globals().saved)['recovery']=='broken original JSON'
manifest=json.loads((MOD/'resources/font/manifest.json').read_text('utf-8'))
font=(MOD/'resources/font/icp_panel.fnt').read_bytes();assert font[:4]==b'BMF\x03';pos=4;blocks={}
while pos<len(font):
    kind,size=struct.unpack_from('<BI',font,pos);pos+=5;blocks[kind]=font[pos:pos+size];pos+=size
ids={struct.unpack_from('<I',blocks[4],i)[0] for i in range(0,len(blocks[4]),20)}
assert ids==set(manifest['glyphs'])
text=''.join(p.read_text('utf-8') for p in MOD.rglob('*.lua'))
assert {ord(c) for c in text if ord(c)>=32}<=ids|{127}
assert list(Image.open(MOD/'resources/font/icp_panel.png').size)==manifest['atlas']
ET.parse(MOD/'metadata.xml');ET.parse(MOD/'resources/gfx/icp/rect.anm2')
report={'lua':'5.3','syntax_files':syntax,'module_test_groups':suite,'runtime_test_groups':runtime_groups,'font_glyphs':len(ids),'offline_passed':True,'game_verified':False,'note':'All game APIs mocked; no game process or console commands used.'}
report['real_json_restart_and_corruption_recovery']=True
report['enum_snapshot_exact_match']=True
report['navigation_regression_groups']=navigation_groups
report['keyboard_compatibility_groups']=keyboard_groups
report['continuous_back_render_groups']=back_groups
(ROOT/'test-artifacts').mkdir(exist_ok=True)
(ROOT/'test-artifacts/mod-offline.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),'utf-8')
print(json.dumps(report,ensure_ascii=False))
