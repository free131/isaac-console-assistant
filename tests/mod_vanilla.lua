-- Loaded without extension globals or callback IDs; fixture already exercised
-- keyboard search, resource execution, navigation, and optional MCM behavior.
assert(PauseMenu==nil and callbacks[9]==nil and callbacks[10]==nil)
assert(nativePauseState==0 and not Game():IsPaused())
local function render() draws={};callbacks[1]();assert(#logs==0,logs[#logs]) end
local function tap(k) keys[k]=true;render();keys[k]=false;render() end
local function has(text) for _,d in ipairs(draws) do if d.text:find(text,1,true) then return true end end end
render();assert(has('普通模式：战斗未暂停，仍会受伤；'))
assert(not has('战斗与计时已暂停') and not hudVisible)
tap(292);assert(saved~='') -- favorite in ordinary mode
tap(297);assert(hudVisible and not Game():IsPaused())
pads[1]={[2]=true};render();pads[1]={};render();render()
assert(has('收藏') and not hudVisible and not Game():IsPaused())
pads[1]={[5]=true};render();pads[1]={};render()
assert(hudVisible and callbacks[2](nil,runtime_player,0,0)==nil)
-- Native menu must still block opening; don't borrow or release its pause.
paused=true;tap(297);assert(hudVisible and paused)
paused=false;tap(297);assert(not hudVisible)
callbacks[6]();assert(hudVisible and nativePauseState==0)
return 4
