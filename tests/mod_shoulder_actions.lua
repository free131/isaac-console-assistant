-- Model native action polling BEFORE MC_POST_RENDER, including staggered shoulders.
local consumed={[8]=0,[9]=0};local previous={}
local function raw(action)
  return pads[1] and pads[1][action==8 and 8 or 11]==true or false
end
local function step(ms)
  clock=ms;frame=frame+1
  if nativePauseState==0 then
    for _,action in ipairs({8,9}) do
      local trigger=callbacks[2](nil,runtime_player,1,action)
      if trigger==nil then trigger=raw(action) and not previous[action] end
      if trigger then consumed[action]=consumed[action]+1 end
      previous[action]=raw(action)
    end
  end
  callbacks[1]();assert(#logs==0,logs[#logs])
end
local function close(ms)
  pads={};step(ms);keys[297]=true;step(ms+1);keys[297]=false;step(ms+2)
  assert(nativePauseState==0)
end
close(0)
-- Both pressed in the same input update: nothing consumes before the instant open.
pads[1]={[8]=true,[11]=true};step(10)
assert(nativePauseState==4 and consumed[8]==0 and consumed[9]==0)
close(20)
-- Either shoulder may arrive one frame earlier; queued actions must be cancelled.
for _,first in ipairs({8,11}) do
  pads[1]={[first]=true};step(100);assert(nativePauseState==0)
  pads[1][first==8 and 11 or 8]=true;step(117)
  assert(nativePauseState==4 and consumed[8]==0 and consumed[9]==0)
  close(130)
end
-- A quick single LB tap is replayed once even if released within the grace window.
pads[1]={[8]=true};step(200);pads={};step(210)
assert(consumed[8]==0);step(289);assert(consumed[8]==0)
step(290);assert(consumed[8]==1);step(307);step(400);assert(consumed[8]==1)
-- A held single RB still activates once, and release does not replay it again.
pads[1]={[11]=true};step(500);step(590);assert(consumed[9]==1)
step(607);pads={};step(620);step(800);assert(consumed[9]==1)
-- Opening by F8 during the buffer cancels a pending bomb rather than firing later.
pads[1]={[8]=true};step(900);keys[297]=true;step(910);keys[297]=false
assert(nativePauseState==4);close(920);step(1100);assert(consumed[8]==1)
-- All three hook types see a consistent delayed pulse in one game frame.
local Hotkey=include('icp/hotkey');local time=0;local down=true
local h=Hotkey.new(function(code) return code==8 and down end,function() return time end)
assert(h:filter_game(8,0,1,1,true,true)==false)
assert(h:filter_game(8,1,1,1,true,true)==false)
assert(h:filter_game(8,2,1,1,true,true)==0)
down=false;time=90
assert(h:filter_game(8,0,1,2,false,true)==true)
assert(h:filter_game(8,1,1,2,false,true)==true)
assert(h:filter_game(8,2,1,2,false,true)==1)
assert(h:filter_game(8,1,1,3,false,true)==nil)
return 5
