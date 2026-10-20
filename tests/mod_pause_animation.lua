-- J835 native pause update precedes Lua rendering and clears completed Dissapear.
local clears=0
local function render()
  frame=frame+1;draws={}
  if nativePauseState~=0 and nativePauseAnimation=='Dissapear' then
    nativePauseState=0;clears=clears+1
  end
  callbacks[1]();assert(#logs==0,logs[#logs])
end
local function key(code) keys[code]=true;render();keys[code]=false;render() end
local function blocked() return callbacks[2](nil,runtime_player,0,0)==false end
-- Regression: failed prior implementation was immediately cleared on frame two.
assert(nativePauseState==4)
render();assert(nativePauseState==4 and nativePauseAnimation=='Idle' and blocked())
for i=1,120 do render();assert(nativePauseState==4 and #draws>0) end
key(297);assert(nativePauseState==0)
for i=1,3 do
  nativePauseAnimation='Dissapear' -- prior native Esc close / menu lifecycle
  key(297);assert(nativePauseState==4 and nativePauseAnimation=='Idle')
  key(262);key(256);assert(nativePauseState==4) -- panel return keeps battle paused
  key(297);assert(nativePauseState==0)
end
-- Current physical controller hotkey also survives the native update phase.
nativePauseAnimation='Dissapear';pads[1]={[2]=true};render()
assert(nativePauseState==4 and nativePauseAnimation=='Idle')
pads={};render();render();assert(nativePauseState==4)
pads[1]={[2]=true};render();pads={};render();assert(nativePauseState==4)
for i=1,2 do buttons[15]=true;render();buttons[15]=false;render() end
assert(nativePauseState==0)
assert(clears==0)
-- A failing sprite initialization must not acquire or hide a native pause.
local Gate=include('icp/pause');local value=0
local gate=Gate.new({available=function() return true end,get=function() return value end,
  set=function(v) value=v end,prepare=function() error('invalid animation') end,
  paused=function() return value~=0 end,open=4,closed=0,log=function() end})
assert(not gate:begin() and value==0 and not gate.owned and gate:hide_native()==nil)
return 3
