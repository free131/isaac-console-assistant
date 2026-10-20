-- Optional MCM adapter. State and persistence belong to this Mod, not MCM.Config.
local M={}
local category='以撒指令面板'
local keys={'KEY_F8','KEY_F9','KEY_F11'}
local buttons={2,3,0,1}
local names={'十字键上','十字键下','十字键左','十字键右'}
local function find(list,value)
  for i,v in ipairs(list) do if v==value then return i end end
  return 1
end
function M.new(state,save)
  local registered=setmetatable({}, {__mode='k'})
  local adapter={}
  function adapter:register(api)
    if type(api)~='table' or type(api.AddSetting)~='function' or type(api.UpdateCategory)~='function'
      or type(api.OptionType)~='table' or not api.OptionType.NUMBER or not api.OptionType.BOOLEAN then return false end
    if registered[api] then return true end
    -- A Lua reload must replace only our category, not append duplicate settings.
    if type(api.RemoveCategory)=='function' then api.RemoveCategory(category) end
    api.UpdateCategory(category,{Info='只配置本面板；不修改原版按键、收藏或历史。'})
    api.AddSetting(category,'按键设置',{
      Type=api.OptionType.NUMBER,Minimum=1,Maximum=#keys,Default=1,
      CurrentSetting=function() return find(keys,state.hotkey) end,
      Display=function() return '键盘开关键：'..state.hotkey:gsub('KEY_','') end,
      OnChange=function(value)
        if keys[value] and state.hotkey~=keys[value] then state.hotkey=keys[value];save() end
      end,
      Info={'F8、F9、F11 三选一；按下立即开关。','面板内的“改键”与本项同步。菜单中按 R 恢复此项默认值。'}
    })
    api.AddSetting(category,'按键设置',{
      Type=api.OptionType.BOOLEAN,Default=true,
      CurrentSetting=function() return state.controllerEnabled end,
      Display=function() return '启用手柄开关：'..(state.controllerEnabled and '开启' or '关闭') end,
      OnChange=function(value)
        if type(value)=='boolean' and state.controllerEnabled~=value then state.controllerEnabled=value;save() end
      end,
      Info={'关闭后十字键恢复原用途，键盘开关仍可使用。','仅控制手柄开关键；不关闭面板内的手柄导航。'}
    })
    api.AddSetting(category,'按键设置',{
      Type=api.OptionType.NUMBER,Minimum=1,Maximum=#buttons,Default=1,
      CurrentSetting=function() return find(buttons,state.controllerButton) end,
      Display=function() return '手柄开关键：'..names[find(buttons,state.controllerButton)] end,
      OnChange=function(value)
        if buttons[value]~=nil and state.controllerButton~=buttons[value] then state.controllerButton=buttons[value];save() end
      end,
      Info={'默认十字键上。选中方向用于开关，不再用于角色移动。','左摇杆仍可导航；LB、RB、LT、RT 不作为开关键。','离开菜单后先松开按键，再按即可立即触发。'}
    })
    registered[api]=true
    return true
  end
  return adapter
end
return M
