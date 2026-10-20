local Adapter=include('icp/mcm')
local State=include('icp/state')
local function api()
  local m={OptionType={NUMBER=1,BOOLEAN=4},categories={other={}},IsVisible=false,removed=0}
  m.UpdateCategory=function(name,info) m.categories[name]=m.categories[name] or {};m.categories[name].info=info end
  m.RemoveCategory=function(name) assert(name=='以撒指令面板');m.categories[name]=nil;m.removed=m.removed+1 end
  m.AddSetting=function(name,sub,setting)
    assert(sub=='按键设置');local c=m.categories[name];c.options=c.options or {};c.options[#c.options+1]=setting
  end
  return m
end
-- Defaults migrate legacy saves without losing history, favorites or run flags.
local incoming={version=1,hotkey='KEY_F11',favorites={['c:1']=true},history={{key='c:1',amount=1,operation='give'}},run={seed='123',flight=true}}
local state=State.load('legacy',function() return incoming end,{['c:1']=true})
assert(state.hotkey=='KEY_F11' and state.controllerEnabled and state.controllerButton==2)
assert(state.favorites['c:1'] and #state.history==1 and state.run.flight)
incoming.controllerEnabled='no';incoming.controllerButton=11
local invalid=State.load('invalid',function() return incoming end,{['c:1']=true})
assert(invalid.controllerEnabled and invalid.controllerButton==2)
local count=0;local adapter=Adapter.new(state,function() count=count+1 end)
assert(not adapter:register(nil) and not adapter:register({}))
local m=api();assert(adapter:register(m));local options=m.categories['以撒指令面板'].options
assert(#options==3 and m.categories.other and options[1].CurrentSetting()==3)
assert(adapter:register(m) and #options==3 and m.removed==1)
options[1].OnChange(2);options[2].OnChange(false);options[3].OnChange(4)
assert(count==3 and state.hotkey=='KEY_F9' and not state.controllerEnabled and state.controllerButton==1)
options[1].OnChange(99);options[2].OnChange('invalid');options[3].OnChange(99)
assert(count==3)
assert(options[1].Display():find('F9') and options[3].Display():find('十字键右'))
-- MCM per-setting reset uses our defaults and leaves user records intact.
for _,s in ipairs(options) do s.OnChange(s.Default) end
assert(state.hotkey=='KEY_F8' and state.controllerEnabled and state.controllerButton==2)
assert(state.favorites['c:1'] and #state.history==1 and state.run.flight)
local reloaded=Adapter.new(state,function() end);assert(reloaded:register(m))
assert(#m.categories['以撒指令面板'].options==3 and m.categories.other)
-- Real entry point: MCM may load after the panel, registration must happen later.
local function render() frame=frame+1;callbacks[1]();assert(#logs==0,logs[#logs]) end
local function key(code) keys[code]=true;render();keys[code]=false;render() end
key(297);assert(nativePauseState==0)
ModConfigMenu=api();render();local current=ModConfigMenu.categories['以撒指令面板'].options
assert(#current==3);render();assert(ModConfigMenu.removed==1)
ModConfigMenu.IsVisible=true
current[1].OnChange(3);current[3].OnChange(4) -- F11 + D-pad Right
local recorded=require('json').decode(saved)
assert(recorded.hotkey=='KEY_F11' and recorded.controllerButton==1 and recorded.controllerEnabled)
assert(#recorded.history>0) -- existing runtime history is retained
-- A configured key held while leaving MCM must not open until released/repressed.
pads[1]={[1]=true};render();ModConfigMenu.IsVisible=false;render();assert(nativePauseState==0)
pads={};render();pads[1]={[2]=true};render();assert(nativePauseState==0)
pads={};render();pads[1]={[1]=true};render();assert(nativePauseState==4)
pads={};render();key(300);assert(nativePauseState==0)
-- Disabling controller opening restores the original direction, preserving F11.
ModConfigMenu.IsVisible=true;current[2].OnChange(false);render();ModConfigMenu.IsVisible=false
pads[1]={[1]=true};render();assert(nativePauseState==0)
assert(callbacks[2](nil,runtime_player,0,1)==nil)
pads={};render();key(300);assert(nativePauseState==4);key(300);assert(nativePauseState==0)
recorded=require('json').decode(saved)
local restored=State.load(saved,function() return recorded end,{['resource:coins']=true})
assert(restored.hotkey=='KEY_F11' and not restored.controllerEnabled and restored.controllerButton==1)
return 6
