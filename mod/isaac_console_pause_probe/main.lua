local mod=RegisterMod('指令面板 · 原版控制台暂停探针',1)
local json=require('json')
local game=Game()
local Probe=include('probe')
local function log(kind,row) Isaac.DebugString('[ICP-PauseProbe] '..kind..' '..json.encode(row)) end
local function key(code)
  local function raw(k)
    if EID and type(EID.BoCSHookInputIsButtonPressed)=='function' then return Input.IsButtonPressed(k,0,true) end
    return Input.IsButtonPressed(k,0)
  end
  return raw(code) and not raw(code%32)
end
local probe=Probe.new({time=Isaac.GetTime,frame=function() return game:GetFrameCount() end,timer=function() return game.TimeCounter end,paused=function() return game:IsPaused() end,grave=function() return key(Keyboard.KEY_GRAVE_ACCENT) end,log=log})
local f6=false
local f7=false
local function save() local ok,err=pcall(function() mod:SaveData(json.encode(probe:report())) end);if not ok then log('save_error',{message=tostring(err)}) end end
-- These are explicit, read-only diagnostic calls entered by the user in the console.
ICPPauseProbe={
  Mark=function(label) local row=probe:snapshot(label or 'manual');Isaac.ConsoleOutput('[ICP-PauseProbe] '..json.encode(row)..'\n');save() end,
  Report=function() Isaac.ConsoleOutput('[ICP-PauseProbe] '..json.encode(probe:report())..'\n');save() end
}
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,function() probe:start();f6=false;f7=false;probe:snapshot('game_started') end)
mod:AddCallback(ModCallbacks.MC_POST_UPDATE,function() probe:update() end)
mod:AddCallback(ModCallbacks.MC_INPUT_ACTION,function(_,entity,hook,button) return probe:input(hook,button) end)
mod:AddCallback(ModCallbacks.MC_POST_RENDER,function()
  if not probe.running then return end
  probe:render()
  local k6,k7=key(Keyboard.KEY_F6),key(Keyboard.KEY_F7)
  if k6 and not f6 then probe:arm() end
  if k7 and not f7 then probe:snapshot('F7_render_key_received');save() end
  f6=k6;f7=k7
  Isaac.RenderText('ICP Pause Probe: F6 = console-hook attempt; F7 = marker',12,8,1,.85,.4,1)
  Isaac.RenderText('Status: '..probe.status..' | Render '..probe.renders..' | Update '..probe.updates,12,21,1,1,1,1)
  Isaac.RenderText('Test only. No game commands. Keep F8 panel closed.',12,34,1,.85,.4,1)
end)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT,function() if probe.running then probe:snapshot('game_exit');save();probe.running=false end end)
