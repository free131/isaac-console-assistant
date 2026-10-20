local M = {}
local valid_hotkeys = {KEY_F8=true, KEY_F9=true, KEY_F11=true}
function M.defaults()
  return {version=1, favorites={}, history={}, hotkey='KEY_F8', controllerEnabled=true, controllerButton=2, run={seed='', flight=false, invincible=false}}
end
function M.load(raw, decode, known)
  local result = M.defaults()
  if not raw or raw == '' then return result end
  local ok, parsed = pcall(decode, raw)
  if not ok or type(parsed) ~= 'table' or parsed.version ~= 1 then
    result.recovery = raw; return result, '记录无法读取，已在新记录中保留原内容备份。'
  end
  if type(parsed.favorites) == 'table' then for key, value in pairs(parsed.favorites) do if known[key] and value == true then result.favorites[key]=true end end end
  if type(parsed.history) == 'table' then
    for _, row in ipairs(parsed.history) do
      if #result.history >= 100 then break end
      if type(row)=='table' and known[row.key] and type(row.amount)=='number' and row.amount==row.amount and row.amount%1==0 and type(row.operation)=='string' then
        result.history[#result.history+1]={key=row.key, amount=row.amount, operation=row.operation, stamp=tostring(row.stamp or '')}
      end
    end
  end
  if valid_hotkeys[parsed.hotkey] then result.hotkey=parsed.hotkey end
  if type(parsed.controllerEnabled)=='boolean' then result.controllerEnabled=parsed.controllerEnabled end
  if type(parsed.controllerButton)=='number' and parsed.controllerButton%1==0 and parsed.controllerButton>=0 and parsed.controllerButton<=3 then result.controllerButton=parsed.controllerButton end
  if type(parsed.run)=='table' then result.run={seed=tostring(parsed.run.seed or ''),flight=parsed.run.flight==true,invincible=parsed.run.invincible==true} end
  if type(parsed.recovery)=='string' then result.recovery=parsed.recovery end
  return result
end
function M.begin_run(state, continued, seed)
  seed=tostring(seed)
  if not continued or state.run.seed ~= seed then state.run={seed=seed,flight=false,invincible=false} end
end
function M.record(state, request, stamp)
  table.insert(state.history,1,{key=request.key,amount=request.amount,operation=request.operation,stamp=tostring(stamp or '')})
  while #state.history>100 do table.remove(state.history) end
end
function M.toggle_favorite(state,key) state.favorites[key]=not state.favorites[key] or nil end
function M.cycle_hotkey(state)
  state.hotkey=({KEY_F8='KEY_F9',KEY_F9='KEY_F11',KEY_F11='KEY_F8'})[state.hotkey] or 'KEY_F8'
end
return M
