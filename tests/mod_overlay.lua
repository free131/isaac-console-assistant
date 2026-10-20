-- Actual entry callbacks, simulated APIs only. Fixture leaves the panel open.
local function tap(k) keys[k]=true;callbacks[1]();keys[k]=false;callbacks[1]() end
assert(priorities[1]==10000 and not hudVisible)
rects={};callbacks[1]()
assert(#rects>0 and rects[1].color[4]==1,'panel background must be opaque')
tap(297);assert(hudVisible,'hotkey close must restore HUD')
hudVisible=false;tap(297);tap(297)
assert(not hudVisible,'already hidden HUD must remain hidden')
hudVisible=true;tap(297);callbacks[7]()
assert(hudVisible,'room change must restore HUD')
callbacks[1]();tap(297);callbacks[6]()
assert(hudVisible,'game exit must restore HUD')
callbacks[5](nil,true);callbacks[1]();tap(297)
local getMouse=Input.GetMousePosition
Input.GetMousePosition=function() error('intentional overlay failure') end
callbacks[1]()
assert(hudVisible and nativePauseState==0,'render failure must restore HUD and pause')
Input.GetMousePosition=getMouse;logs={};callbacks[1]() -- release the error-close guard
tap(297);assert(not hudVisible)
ModConfigMenu={IsVisible=true};callbacks[1]()
assert(hudVisible,'external menu close must restore HUD')
return 4
