-- Ordinary gameplay must use the original engine action values without replay.
local function render(ms) clock=ms;frame=frame+1;callbacks[1]();assert(#logs==0,logs[#logs]) end
local function key(k,ms) keys[k]=true;render(ms);keys[k]=false;render(ms+1) end
key(297,0);assert(nativePauseState==0)
local original=Input.IsActionPressed
local actionReads=0
Input.IsActionPressed=function(...) actionReads=actionReads+1;return original(...) end
local function untouched()
  local count=actionReads
  for _,action in ipairs({8,9,10}) do
    for hook=0,2 do assert(callbacks[2](nil,runtime_player,hook,action)==nil) end
  end
  assert(actionReads==count) -- no nested reads that could consume native triggers
end
-- A single shoulder stays unmodified on its first frame, held, and released.
for _,code in ipairs({8,11}) do
  pads[1]={[code]=true};untouched();render(10);untouched();render(1000);untouched()
  pads={};render(1001);untouched()
end
-- Ordinary keyboard/gamepad controls all fall through, regardless of elapsed time.
for action=0,28 do
  for hook=0,2 do assert(callbacks[2](nil,runtime_player,hook,action)==nil) end
end
-- LB+RB is no longer a hotkey and must not intercept either original action.
pads[1]={[8]=true,[11]=true};untouched();render(1900)
assert(nativePauseState==0);untouched();pads={};render(1901)
-- D-pad Up alone now suppresses movement before render and immediately opens.
pads[1]={[2]=true}
assert(callbacks[2](nil,runtime_player,1,2)==false)
render(2000);assert(nativePauseState==4)
pads={};render(2001)
key(297,2100);assert(nativePauseState==0);untouched()
-- Two different controllers never cause single actions to be intercepted.
runtime_player.ControllerIndex=0
pads={[1]={[8]=true},[2]={[11]=true}};untouched();render(2200);untouched()
pads={};render(2201)
Input.IsActionPressed=original
return 4
