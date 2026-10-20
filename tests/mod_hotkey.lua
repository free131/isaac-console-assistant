local function render(ms) clock=ms;frame=frame+1;callbacks[1]();assert(#logs==0,logs[#logs]) end
local function key(k,ms) keys[k]=true;render(ms);keys[k]=false;render(ms+1) end
local function blocked() return callbacks[2](nil,runtime_player,0,0)==false end
key(297,0);assert(nativePauseState==0)
-- Physical D-pad Up opens on the first render without a clock advance.
pads[1]={[2]=true};render(0);assert(nativePauseState==4 and blocked())
for i=1,60 do render(0);assert(nativePauseState==4) end
pads={};render(1)
-- The next Up press navigates to search; only B can return to the root and close.
pads[1]={[2]=true};render(2);assert(nativePauseState==4 and blocked())
pads={};render(3);assert(nativePauseState==4)
for i=1,2 do buttons[15]=true;render(3);buttons[15]=false;render(3) end
assert(nativePauseState==0 and not blocked())
-- Keyboard Up and analog/menu Up are navigation, not global panel hotkeys.
key(265,4);buttons[22]=true;render(5);buttons[22]=false;render(6)
assert(nativePauseState==0)
-- Both old bumpers remain normal gameplay actions; neither opens the panel.
pads[1]={[8]=true,[11]=true};render(7);render(1000)
assert(nativePauseState==0 and not blocked());pads={};render(1001)
-- Do not open over another menu or from a carried key held on leaving it.
for i,menu in ipairs({'mcm','goodtrip','native'}) do
  if menu=='mcm' then ModConfigMenu={IsVisible=true}
  elseif menu=='goodtrip' then gt={mapHeld=true} else nativePauseState=2 end
  pads[1]={[2]=true};render(2000+i*10)
  ModConfigMenu=nil;gt=nil;nativePauseState=0;render(2001+i*10)
  assert(nativePauseState==0)
  pads={};render(2002+i*10)
end
-- A keyboard player can use another pad, but a controller player owns its hotkey.
runtime_player.ControllerIndex=1;pads[2]={[2]=true};render(3000)
assert(nativePauseState==0);pads={};render(3001)
runtime_player.ControllerIndex=0;pads[2]={[2]=true};render(3002)
assert(nativePauseState==4);pads={};render(3003);key(297,3004)
assert(nativePauseState==0)
-- Repeated physical taps work; keyboard F8 is retained.
for i=1,3 do
  pads[1]={[2]=true};render(4000+i*10);pads={};render(4001+i*10)
  assert(nativePauseState==4)
  key(297,4002+i*10);assert(nativePauseState==0)
end
return 5
