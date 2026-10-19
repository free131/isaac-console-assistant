local mod=RegisterMod('以撒游戏内指令面板',1)
local Search=include('icp/search')
local State=include('icp/state')
local Actions=include('icp/actions')
local Panel=include('icp/panel')
local Renderer=include('icp/render')
local json=require('json')
local catalog=Search.prepare(include('icp/catalog'))
local raw=mod:HasData() and mod:LoadData() or ''
local state,warning=State.load(raw,json.decode,catalog.by_key)
local game=Game()
local running=false
local reading=false
local held={}
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
local view=Renderer.new(Panel.categories,state)
panel.message=warning or 'PageUp / PageDown 切换分类；点击右上改键。'
local function menus_open() return game:IsPaused() or (ModConfigMenu and ModConfigMenu.IsVisible==true) or (gt and gt.mapHeld==true) or (DeadSeaScrollsMenu and DeadSeaScrollsMenu.Opened==true) end
local function key(code) return code and Input.IsButtonPressed(code,0) or false end
local function edge(id,down,repeatable)
  local n=held[id] or 0;held[id]=down and n+1 or 0
  return down and (n==0 or (repeatable and n>20 and n%5==0))
end
local function action(code,index)
  reading=true;local ok,v=pcall(Input.IsActionPressed,code,index);reading=false
  return ok and v or false
end
local function release_ready(index)
  for code=32,348 do if key(code) then return false end end
  for code=0,26 do if action(code,index) then return false end end
  return not Input.IsMouseBtnPressed(0)
end
local function click(id)
  if not id then return end
  if id:sub(1,4)=='cat:' then panel.category=id:sub(5);panel:refresh(game:IsGreedMode())
  elseif id:sub(1,4)=='row:' then panel:select(tonumber(id:sub(5)))
  elseif id=='clear' then panel:set_query('')
  elseif id=='prev' then panel:select(panel.selected-8)
  elseif id=='next' then panel:select(panel.selected+8)
  elseif id=='plus' then panel:adjust(1)
  elseif id=='minus' then panel:adjust(-1)
  elseif id=='operation' then panel:toggle_operation()
  elseif id=='favorite' then panel:favorite()
  elseif id=='execute' then panel:execute()
  elseif id=='delete' then panel:history_delete()
  elseif id=='clear-history' then
    if panel.clearConfirm and panel.clearConfirm>panel.tick then state.history={};panel.clearConfirm=nil;save();panel:refresh(game:IsGreedMode()) else panel.clearConfirm=panel.tick+240;panel.message='再次点击“清历史”确认清空。' end
  elseif id=='hotkey' then State.cycle_hotkey(state);save();panel.message='打开 / 关闭热键已设为 '..state.hotkey:gsub('KEY_','') end
end
local function render()
  panel.tick=panel.tick+1
  local p=player();local index=p and p.ControllerIndex or 0
  local toggle=edge('toggle',key(Keyboard[state.hotkey]))
  if menus_open() or not running then
    if panel.open then panel:close() end
    if panel.guard and release_ready(index) then panel.guard=false;held={} end
    return
  end
  if toggle then
    if panel.open then panel:close() elseif not panel.guard then panel.open=true;panel.guard=true;panel:refresh(game:IsGreedMode()) end
  end
  if panel.guard then if release_ready(index) then panel.guard=false;held={} end;return end
  if not panel.open then return end
  local function press(name,k,a,rep) return edge(name,key(k) or (a and action(a,index)),rep) end
  if press('back',Keyboard.KEY_ESCAPE,ButtonAction.ACTION_MENUBACK) then panel:back();return end
  if press('up',Keyboard.KEY_UP,ButtonAction.ACTION_MENUUP,true) then panel:select(panel.selected-1) end
  if press('down',Keyboard.KEY_DOWN,ButtonAction.ACTION_MENUDOWN,true) then panel:select(panel.selected+1) end
  if press('left',Keyboard.KEY_LEFT,ButtonAction.ACTION_MENULEFT,true) then panel:adjust(-1) end
  if press('right',Keyboard.KEY_RIGHT,ButtonAction.ACTION_MENURIGHT,true) then panel:adjust(1) end
  if press('category',Keyboard.KEY_PAGE_DOWN,ButtonAction.ACTION_MENURT) then panel:category_move(1) end
  if press('category-back',Keyboard.KEY_PAGE_UP,ButtonAction.ACTION_MENULT) then panel:category_move(-1) end
  if press('mode',Keyboard.KEY_F2,nil) then panel:toggle_operation() end
  if press('favorite',Keyboard.KEY_F3,nil) then panel:favorite() end
  if press('delete',Keyboard.KEY_DELETE,nil) then panel:history_delete() end
  if press('erase',Keyboard.KEY_BACKSPACE,nil,true) then panel:set_query(panel.query:sub(1,-2)) end
  local ctrl=key(Keyboard.KEY_LEFT_CONTROL) or key(Keyboard.KEY_RIGHT_CONTROL)
  local clearQuery=edge('clear-query',key(Keyboard.KEY_K))
  if ctrl and clearQuery then panel:set_query('') end
  if not ctrl then
    for code=48,90 do if (code<=57 or code>=65) and edge('text'..code,key(code),true) then panel:set_query(panel.query..string.char(code):lower()) end end
    if edge('text-minus',key(Keyboard.KEY_MINUS),true) then panel:set_query(panel.query..'-') end
    if edge('text-space',key(Keyboard.KEY_SPACE),true) then panel:set_query(panel.query..' ') end
  end
  if press('confirm',Keyboard.KEY_ENTER,ButtonAction.ACTION_MENUCONFIRM) then panel:execute() end
  if not panel.open then return end
  view:draw(panel)
  if edge('mouse',Input.IsMouseBtnPressed(0)) then local pos=Input.GetMousePosition(false);click(view:hit(pos.X,pos.Y)) end
end
mod:AddCallback(ModCallbacks.MC_POST_RENDER,function()
  local ok,err=pcall(render)
  if not ok then reading=false;panel:close();Isaac.DebugString('ICP panel error: '..tostring(err)) end
end)
mod:AddCallback(ModCallbacks.MC_INPUT_ACTION,function(_,entity,hook,button)
  if not reading and (panel.open or panel.guard) and (not entity or entity:ToPlayer()) and button~=ButtonAction.ACTION_FULLSCREEN and button~=ButtonAction.ACTION_MUTE then
    if hook==InputHook.GET_ACTION_VALUE then return 0 else return false end
  end
end)
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,function(_,p,flag) actions:on_cache(p,flag) end)
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,function(_,entity) return actions:on_damage(entity) end,EntityType.ENTITY_PLAYER)
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,function(_,continued)
  running=true;State.begin_run(state,continued,game:GetSeeds():GetStartSeed());actions:refresh_flight();panel:close();save()
end)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT,function() panel:close();save();running=false end)
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,function() if panel.open then panel:close() end end)
