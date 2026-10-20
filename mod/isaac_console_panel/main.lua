local mod=RegisterMod('以撒游戏内指令面板',1)
local Search=include('icp/search')
local State=include('icp/state')
local Actions=include('icp/actions')
local Panel=include('icp/panel')
local Renderer=include('icp/render')
local NativePause=include('icp/pause')
local Hotkey=include('icp/hotkey')
local json=require('json')
local catalog=Search.prepare(include('icp/catalog'))
local raw=mod:HasData() and mod:LoadData() or ''
local state,warning=State.load(raw,json.decode,catalog.by_key)
local game=Game()
local pause=NativePause.new({
  available=function() return PauseMenu and type(PauseMenu.GetState)=='function' and type(PauseMenu.SetState)=='function' and ModCallbacks.MC_PRE_PAUSE_SCREEN_RENDER~=nil end,
  get=function() return PauseMenu.GetState() end,set=function(value) PauseMenu.SetState(value) end,
  -- J835: state 1 still runs native PauseScreen::ProcessInput (raw Esc/Enter).
  -- Private state 4 stays paused but bypasses native states 0/1/2 and popup 3.
  -- Rendering is suppressed only while this panel owns that state.
  open=4,closed=0,paused=function() return game:IsPaused() end,
  log=function(kind,message) Isaac.DebugString('[ICP-Pause] '..kind..' '..tostring(message)) end
})
local running=false
local reading=false
local held={}
local keyboardErrorReported=false
local function player() if running and game:GetNumPlayers()>0 then return Isaac.GetPlayer(0) end end
local function save()
  local ok,err=pcall(function() mod:SaveData(json.encode(state)) end)
  if not ok then Isaac.DebugString('ICP save failed: '..tostring(err)) end
  return ok
end
local actions=Actions.new({player=player,game=function() return game end,execute=Isaac.ExecuteCommand,flying_flag=CacheFlag.CACHE_FLYING},state,catalog)
local panel
panel=Panel.new(Search,catalog,state,actions,function() if not save() then panel.message='操作已执行，但记录保存失败。' end end,function(req) State.record(state,req,game:GetFrameCount()) end)
-- Forward reference is intentionally assigned after construction for save errors.
local view=Renderer.new(Panel.categories,state,Panel.keyboard)
panel.message=warning or '键盘用英文输入法；F1 切区，方向导航，Enter 确认。'
local function menus_open() return (game:IsPaused() and not pause.owned) or (ModConfigMenu and ModConfigMenu.IsVisible==true) or (gt and gt.mapHeld==true) or (DeadSeaScrollsMenu and DeadSeaScrollsMenu.Opened==true) end
local function raw_key(code)
  -- EID's crafting-search wrapper exposes force=true for other input owners.
  -- Do not replace its global functions or change its search settings.
  if EID and type(EID.BoCSHookInputIsButtonPressed)=='function' then return Input.IsButtonPressed(code,0,true) end
  return Input.IsButtonPressed(code,0)
end
local function key(code)
  if type(code)~='number' then return false end
  local previous=reading;reading=true
  local ok,down=pcall(function()
    -- Repentance can alias controller buttons to keyboard codes modulo 32.
    return raw_key(code) and not raw_key(code%32)
  end)
  reading=previous
  if not ok and not keyboardErrorReported then keyboardErrorReported=true;Isaac.DebugString('ICP keyboard input error: '..tostring(down)) end
  return ok and down or false
end
local function edge(id,down,repeatable)
  local n=held[id] or 0;held[id]=down and n+1 or 0
  return down and (n==0 or (repeatable and n>20 and n%5==0))
end
local function action(code,index)
  reading=true;local ok,v=pcall(Input.IsActionPressed,code,index);reading=false
  return ok and v or false
end
local function pad_action(code,index)
  if index>0 then return action(code,index) end
  for controller=1,4 do if action(code,controller) then return true end end
  return false
end
local function pad_button(code,index)
  local previous=reading;reading=true
  local ok,down=pcall(Input.IsButtonPressed,code,index)
  reading=previous
  return ok and down or false
end
local chord=Hotkey.new(pad_button,function() return Isaac.GetTime() end)
local function release_ready(index)
  for _,code in pairs(Keyboard) do if type(code)=='number' and code>=32 and key(code) then return false end end
  for code=0,26 do if pad_action(code,index) then return false end end
  for controller=1,4 do for code=0,15 do if pad_button(code,controller) then return false end end end
  return not Input.IsMouseBtnPressed(0)
end
local function click(id)
  if not id then return end
  if id:sub(1,4)=='cat:' then panel.focus='categories';panel.category=id:sub(5);panel:refresh(game:IsGreedMode())
  elseif id:sub(1,4)=='row:' then panel.focus='results';panel:select(tonumber(id:sub(5)))
  elseif id=='clear' then panel:set_query('')
  elseif id=='search' then panel:open_search()
  elseif id:sub(1,3)=='vk:' then panel.keyboardIndex=tonumber(id:sub(4));panel:keyboard_confirm()
  elseif id=='prev' then panel:select(panel.selected-8)
  elseif id=='next' then panel:select(panel.selected+8)
  elseif id=='plus' or id=='quantity' then panel:adjust(1)
  elseif id=='minus' then panel:adjust(-1)
  elseif id=='operation' then panel:toggle_operation()
  elseif id=='favorite' then panel:favorite()
  elseif id=='execute' then panel:execute()
  elseif id=='delete' then panel:history_delete()
  elseif id=='clear-history' then
    if panel.clearConfirm and panel.clearConfirm>panel.tick then state.history={};panel.clearConfirm=nil;save();panel:refresh(game:IsGreedMode()) else panel.clearConfirm=panel.tick+240;panel.message='再次确认“清历史”以清空记录。' end
  elseif id=='hotkey' then State.cycle_hotkey(state);save();panel.message='打开 / 关闭热键已设为 '..state.hotkey:gsub('KEY_','')
  elseif id=='close' then panel:close() end
end
local function edit_query()
  if edge('erase',key(Keyboard.KEY_BACKSPACE),true) then panel:set_query(panel.query:sub(1,-2)) end
  local ctrl=key(Keyboard.KEY_LEFT_CONTROL) or key(Keyboard.KEY_RIGHT_CONTROL)
  local clearQuery=edge('clear-query',key(Keyboard.KEY_K))
  if ctrl and clearQuery then panel:set_query('') end
  if not ctrl then
    for code=48,90 do if (code<=57 or code>=65) and edge('text'..code,key(code),true) then panel:set_query(panel.query..string.char(code):lower()) end end
    if edge('text-minus',key(Keyboard.KEY_MINUS),true) then panel:set_query(panel.query..'-') end
    if edge('text-space',key(Keyboard.KEY_SPACE),true) then panel:set_query(panel.query..' ') end
  end
end
local function render()
  panel.tick=panel.tick+1
  if pause.owned and not pause:valid() and panel.open then panel:close() end
  local p=player();local index=p and p.ControllerIndex or 0
  local externalMenu=menus_open()
  if panel.open or panel.guard or externalMenu or not running then chord:cancel_game() end
  local comboToggle=chord:update(running and not externalMenu,index)
  local toggle=edge('toggle',key(Keyboard[state.hotkey])) or comboToggle
  if externalMenu or not running then
    if panel.open then panel:close() end
    if panel.guard and release_ready(index) then panel.guard=false;held={};pause:finish() end
    return
  end
  if toggle then
    if panel.open then panel:close() elseif not panel.guard then
      local ok,message=pause:begin()
      if ok then panel.open=true;panel.guard=true;panel.focus='results';panel.control=1;panel:refresh(game:IsGreedMode())
      else panel.message=message;panel.noticeUntil=panel.tick+240 end
    end
  end
  if panel.guard then if release_ready(index) then panel.guard=false;held={};if not panel.open then pause:finish() end end;return end
  if not panel.open then if panel.noticeUntil and panel.noticeUntil>panel.tick then view:notice(panel.message) end;return end
  -- Index 0 includes the keyboard's menu mappings (space, Q, E, arrows).
  -- Physical keyboard keys are read above; only poll menu actions for a gamepad.
  local function press(name,k,a,rep) return edge(name,key(k) or (a and pad_action(a,index)),rep) end
  if press('back',Keyboard.KEY_ESCAPE,ButtonAction.ACTION_MENUBACK) then
    panel:back()
    if panel.open then view:draw(panel,Isaac.WorldToScreen(Input.GetMousePosition(true))) end
    return
  end
  if panel.editing then
    if press('up',Keyboard.KEY_UP,ButtonAction.ACTION_MENUUP,true) then panel:keyboard_move(0,-1) end
    if press('down',Keyboard.KEY_DOWN,ButtonAction.ACTION_MENUDOWN,true) then panel:keyboard_move(0,1) end
    if press('left',Keyboard.KEY_LEFT,ButtonAction.ACTION_MENULEFT,true) then panel:keyboard_move(-1,0) end
    if press('right',Keyboard.KEY_RIGHT,ButtonAction.ACTION_MENURIGHT,true) then panel:keyboard_move(1,0) end
    edit_query()
    if press('confirm',Keyboard.KEY_ENTER,ButtonAction.ACTION_MENUCONFIRM) then panel:keyboard_confirm() end
    local pos=Isaac.WorldToScreen(Input.GetMousePosition(true));view:draw(panel,pos)
    if edge('mouse',Input.IsMouseBtnPressed(0)) then click(view:hit(pos.X,pos.Y)) end
    return
  end
  if press('up',Keyboard.KEY_UP,ButtonAction.ACTION_MENUUP,true) then panel:navigate(0,-1) end
  if press('down',Keyboard.KEY_DOWN,ButtonAction.ACTION_MENUDOWN,true) then panel:navigate(0,1) end
  if press('left',Keyboard.KEY_LEFT,ButtonAction.ACTION_MENULEFT,true) then panel:navigate(-1,0) end
  if press('right',Keyboard.KEY_RIGHT,ButtonAction.ACTION_MENURIGHT,true) then panel:navigate(1,0) end
  if press('focus',Keyboard.KEY_F1,not chord.active and ButtonAction.ACTION_MENURT) then panel:focus_move(1) end
  if press('focus-back',nil,not chord.active and ButtonAction.ACTION_MENULT) then panel:focus_move(-1) end
  if press('category',Keyboard.KEY_PAGE_DOWN,nil) then panel:category_move(1) end
  if press('category-back',Keyboard.KEY_PAGE_UP,nil) then panel:category_move(-1) end
  if press('mode',Keyboard.KEY_F2,nil) then panel:toggle_operation() end
  if press('favorite',Keyboard.KEY_F3,nil) then panel:favorite() end
  if press('delete',Keyboard.KEY_DELETE,nil) then panel:history_delete() end
  edit_query()
  if press('confirm',Keyboard.KEY_ENTER,ButtonAction.ACTION_MENUCONFIRM) then click(panel:confirm_id()) end
  if not panel.open then return end
  local pos=Isaac.WorldToScreen(Input.GetMousePosition(true))
  view:draw(panel,pos)
  if edge('mouse',Input.IsMouseBtnPressed(0)) then click(view:hit(pos.X,pos.Y)) end
end
mod:AddCallback(ModCallbacks.MC_POST_RENDER,function()
  local ok,err=pcall(render)
  if not ok then reading=false;panel:close();pause:finish();Isaac.DebugString('ICP panel error: '..tostring(err)) end
end)
if ModCallbacks.MC_PRE_PAUSE_SCREEN_RENDER then
  mod:AddCallback(ModCallbacks.MC_PRE_PAUSE_SCREEN_RENDER,function() return pause:hide_native() end)
end
mod:AddCallback(ModCallbacks.MC_INPUT_ACTION,function(_,entity,hook,button)
  if reading or (entity and not entity:ToPlayer()) then return end
  local p=player();local index=p and p.ControllerIndex or 0
  local enabled=running and not menus_open()
  local _,both=chord:sample(index)
  local comboHeld=enabled and (both~=nil or chord.active)
  if panel.open or panel.guard or comboHeld then
    chord:cancel_game()
    if hook==InputHook.GET_ACTION_VALUE then return 0 else return false end
  end
  if button==ButtonAction.ACTION_BOMB or button==ButtonAction.ACTION_ITEM or button==ButtonAction.ACTION_PILLCARD then
    return chord:filter_game(button,hook,index,game:GetFrameCount(),enabled and action(button,index),enabled)
  end
end)
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,function(_,p,flag) actions:on_cache(p,flag) end)
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,function(_,entity) return actions:on_damage(entity) end,EntityType.ENTITY_PLAYER)
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,function(_,continued)
  pause:finish();running=true;State.begin_run(state,continued,game:GetSeeds():GetStartSeed());actions:refresh_flight();panel:close();save()
end)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT,function() panel:close();pause:finish();save();running=false end)
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,function() if panel.open then panel:close() end;pause:finish() end)
