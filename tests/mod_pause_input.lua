-- J835 PauseScreen::ProcessInput runs before Lua rendering, outside MC_INPUT_ACTION.
-- Native OPEN(1) handles Esc/Start/B and Enter/A even when native rendering is hidden.
local nativeEvents=0
local function render()
  frame=frame+1;draws={}
  if nativePauseState==1 then
    if keys[256] or buttons[15] or buttons[12] then
      nativeEvents=nativeEvents+1;nativePauseState=0
    elseif keys[257] or buttons[14] then
      nativeEvents=nativeEvents+1;nativePauseState=2
    end
  end
  callbacks[1]()
  assert(#logs==0,logs[#logs])
end
local function key(k) keys[k]=true;render();keys[k]=false;render() end
local function blocked() return callbacks[2](nil,runtime_player,0,0)==false end
assert(Game():IsPaused() and blocked())
-- Enter and Esc must affect only panel navigation, not the hidden menu.
key(262);keys[256]=true
for i=1,30 do render();assert(nativePauseState==4 and blocked() and #draws>0) end
keys[256]=false;render()
for i=1,4 do key(256);assert(nativePauseState==4 and blocked()) end
buttons[15]=true;render();buttons[15]=false;render()
assert(nativePauseState==0 and not blocked());key(297);assert(nativePauseState==4)
-- Close, release, and reopen repeatedly after returning from details or the root.
for i=1,10 do
  key(297);assert(nativePauseState==0 and not blocked())
  key(297);assert(nativePauseState==4 and blocked())
  key(262);key(256);key(257)
  assert(nativePauseState==4 and blocked())
end
assert(nativeEvents==0)
key(297);assert(nativePauseState==0 and not blocked())
-- A real native pause opened afterwards is still owned and operated by the game.
nativePauseState=1;key(256)
assert(nativeEvents==1 and nativePauseState==0 and not blocked())
return 3
