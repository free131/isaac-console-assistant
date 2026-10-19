-- Own only the native pause state acquired by this panel.
local M={}
function M.new(env)
  local p={owned=false,error=nil}
  function p:available() return env.available() end
  function p:begin()
    if self.owned then return true end
    if not self:available() then return false,'暂停组件未加载，面板暂不打开。' end
    local ok,result=pcall(function()
      if env.get()~=env.closed or env.paused() then return false end
      env.set(env.open)
      if env.get()~=env.open or not env.paused() then
        env.set(env.closed);return false
      end
      return true
    end)
    if not ok or not result then
      self.error=not ok and tostring(result) or '原生暂停未就绪'
      env.log('pause_begin_failed',self.error)
      return false,'无法取得原生暂停，请先关闭其他菜单。'
    end
    self.owned=true;self.error=nil;env.log('pause_acquired','native_pause_menu')
    return true
  end
  function p:finish()
    if not self.owned then return true end
    self.owned=false
    local ok,err=pcall(function()
      -- If a different native menu took ownership, leave it visible and intact.
      if env.get()==env.open then env.set(env.closed) end
    end)
    if not ok then self.error=tostring(err);env.log('pause_release_failed',self.error);return false end
    env.log('pause_released','native_pause_menu');return true
  end
  function p:valid()
    if not self.owned then return false end
    local ok,value=pcall(env.get)
    if not ok or value~=env.open then self.owned=false;env.log('pause_lost','external state change: '..tostring(value));return false end
    return true
  end
  function p:hide_native()
    if self:valid() then return false end
  end
  return p
end
return M
