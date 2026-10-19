local function render() frame=frame+1;draws={};callbacks[1]() end
local function key(k) keys[k]=true;render();keys[k]=false;render() end
local function blocked() return callbacks[2](nil,runtime_player,0,0)==false end
-- The real main.lua must acquire native pause and hide its native input/render path.
assert(nativePauseState==4 and Game():IsPaused() and callbacks[9]()==false)
key(262);key(256);assert(nativePauseState==4 and blocked()) -- returning is not closing
keys[257]=true;render();keys[297]=true;render();keys[297]=false;render()
assert(nativePauseState==4 and callbacks[9]()==false and blocked()) -- held Enter guards resume
keys[257]=false;render();assert(nativePauseState==0 and callbacks[9]()==nil and not blocked())
-- Missing extension refuses to open, instead of claiming a fake safe pause.
local native=PauseMenu;PauseMenu=nil;key(297);assert(not blocked() and nativePauseState==0);PauseMenu=native
key(297);assert(nativePauseState==4 and blocked())
-- Never release a pause acquired by a different menu.
nativePauseState=2;render();render();assert(nativePauseState==2 and callbacks[9]()==nil)
nativePauseState=0;render();key(297);assert(nativePauseState==4)
-- Room transition, new game and exit release the owned pause.
callbacks[7]();render();assert(nativePauseState==0)
key(297);callbacks[5](nil,false);render();assert(nativePauseState==0)
key(297);callbacks[6]();assert(nativePauseState==0)
-- Pure state module: unavailable / acquisition failure / release error are fail-open.
local Gate=include('icp/pause');local value=0;local available=true;local messages={}
local env={available=function() return available end,get=function() return value end,set=function(s) value=s end,closed=0,open=1,paused=function() return value~=0 end,log=function(a,b) messages[#messages+1]=a end}
local gate=Gate.new(env);assert(gate:begin() and value==1 and gate:hide_native()==false);assert(gate:finish() and value==0)
available=false;assert(not gate:begin());available=true
value=2;assert(not gate:begin() and value==2);value=0
env.set=function() error('native set failure') end;assert(not gate:begin() and not gate.owned and gate:hide_native()==nil)
env.set=function(s) value=s end;assert(gate:begin());env.set=function() error('release failure') end
assert(not gate:finish() and not gate.owned and gate:hide_native()==nil)
return 5
