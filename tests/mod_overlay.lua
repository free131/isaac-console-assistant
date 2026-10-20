-- Actual entry callbacks, simulated APIs only. Fixture leaves the panel open.
local function tap(k) keys[k]=true;callbacks[1]();keys[k]=false;callbacks[1]() end
assert(priorities[1]==10000 and priorities[10]==10000 and not hudVisible)
-- EID draws in HUD_RENDER under REPENTOGON, after POST_RENDER regardless of
-- priorities within that earlier phase. Require no panel paint before that.
draws={};rects={};postRender()
assert(#draws==0 and #rects==0,'input phase must not paint the panel')
draws[#draws+1]={text='simulated EID HUD phase'}
callbacks[10]()
assert(draws[1].text=='simulated EID HUD phase' and #rects>0)
local n=#draws;callbacks[10]();assert(#draws==n,'paint request must be consumed once')
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
-- A failure during the actual late paint must also release HUD and pause.
ModConfigMenu=nil;callbacks[1]();tap(297)
local oldColor=Color;Color=function() error('intentional late paint failure') end
callbacks[1]();assert(hudVisible and nativePauseState==0)
Color=oldColor;logs={}
return 6
