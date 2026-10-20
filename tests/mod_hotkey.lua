local function render(ms) clock=ms;frame=frame+1;callbacks[1]();assert(#logs==0,logs[#logs]) end
local function key(k,ms) keys[k]=true;render(ms);keys[k]=false;render(ms+1) end
local function blocked() return callbacks[2](nil,runtime_player,0,0)==false end
-- Runtime bootstrap leaves the panel open; close with the unchanged keyboard hotkey.
key(297,0);assert(nativePauseState==0)
pads[1]={[8]=true};render(10)
assert(nativePauseState==0 and not blocked()) -- ordinary single bumper is preserved
pads[1][11]=true;render(20);assert(nativePauseState==0 and blocked())
render(619);assert(nativePauseState==0)
render(620);assert(nativePauseState==4 and blocked())
render(5000);assert(nativePauseState==4) -- long hold never repeats
pads[1][8]=false;render(5001);assert(nativePauseState==4 and blocked())
pads[1][11]=false;render(5002);assert(nativePauseState==4)
-- Close through the same chord, retain pause until both physical bumpers release.
pads[1]={[8]=true,[11]=true};render(6000);render(6600)
assert(nativePauseState==4 and blocked())
pads[1][8]=false;render(6601);assert(nativePauseState==4)
pads[1][11]=false;render(6602);assert(nativePauseState==0 and not blocked())
-- Short taps and a new hold interrupted by one bumper cannot open.
pads[1]={[8]=true,[11]=true};render(7000);pads[1]={};render(7500)
assert(nativePauseState==0)
pads[1]={[8]=true,[11]=true};render(8000);pads[1][8]=false;render(8300)
pads[1][8]=true;render(8500);render(9099);assert(nativePauseState==0)
render(9100);assert(nativePauseState==4)
pads={};render(9101);key(297,9200);assert(nativePauseState==0)
-- No stacking with MCM or GoodTrip, including carrying a held chord out of a menu.
for i,menu in ipairs({'mcm','goodtrip','native'}) do
  if menu=='mcm' then ModConfigMenu={IsVisible=true}
  elseif menu=='goodtrip' then gt={mapHeld=true} else nativePauseState=2 end
  pads[1]={[8]=true,[11]=true};render(10000+i*2000);render(11000+i*2000)
  ModConfigMenu=nil;gt=nil;nativePauseState=0;render(11100+i*2000)
  assert(nativePauseState==0)
  pads={};render(11200+i*2000)
end
-- Keyboard player can use a controller, but two separate pads cannot form a chord.
runtime_player.ControllerIndex=0
pads={[1]={[8]=true},[2]={[11]=true}};render(20000);render(21000)
assert(nativePauseState==0)
pads={};render(21001);pads={[2]={[8]=true,[11]=true}}
render(22000);render(22600);assert(nativePauseState==4)
pads={};render(22601);key(297,23000);assert(nativePauseState==0)
-- Timing is milliseconds, independent of game update frames and render frequency.
local Hotkey=include('icp/hotkey');local down={};local time=0
local h=Hotkey.new(function(code,index) return down[index] and down[index][code] or false end,function() return time end)
down[1]={[8]=true,[11]=true};assert(not h:update(true,1))
time=599;assert(not h:update(true,1));time=600;assert(h:update(true,1))
time=10000;assert(not h:update(true,1));down[1][8]=false;assert(not h:update(true,1))
down[1]={};assert(not h:update(true,1));down[1]={[8]=true,[11]=true}
assert(not h:update(true,1));time=10600;assert(h:update(true,1))
return 5
