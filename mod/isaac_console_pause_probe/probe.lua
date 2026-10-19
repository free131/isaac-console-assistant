-- Dependency-injected diagnostic state; observations never imply engine support.
local M={}
function M.new(env)
  local p={running=false,renders=0,updates=0,marks={},samples={},emitted={},status='idle'}
  function p:snapshot(label)
    local s={label=tostring(label),ms=env.time(),renders=self.renders,updates=self.updates,game_frame=env.frame(),timer=env.timer(),paused=env.paused()}
    local previous=self.marks[#self.marks]
    if previous then s.delta={ms=s.ms-previous.ms,renders=s.renders-previous.renders,updates=s.updates-previous.updates,game_frame=s.game_frame-previous.game_frame,timer=s.timer-previous.timer} end
    self.marks[#self.marks+1]=s;while #self.marks>32 do table.remove(self.marks,1) end
    env.log('mark',s);return s
  end
  function p:start()
    self.running=true;self.renders=0;self.updates=0;self.marks={};self.samples={};self.emitted={};self.deadline=nil;self.status='idle';self.lastRender=nil
  end
  function p:arm()
    if not self.running then return false end
    self.emitted={};self.deadline=env.time()+1000;self.emitFrame=nil;self.status='armed'
    self:snapshot('F6_before_hook_request');return true
  end
  function p:input(hook,button)
    if not self.running or button~=28 then return nil end
    if #self.samples<16 then
      local row={hook=hook,ms=env.time(),renders=self.renders,updates=self.updates,physical_grave=env.grave()}
      self.samples[#self.samples+1]=row;env.log('console_hook',row)
    end
    if not self.deadline or env.time()>=self.deadline or self.emitted[hook] then return nil end
    if hook~=0 and hook~=1 and hook~=2 then return nil end
    local frame=env.frame()
    if self.emitFrame and frame~=self.emitFrame then return nil end
    self.emitFrame=frame;self.emitted[hook]=true;self.status='hook_value_emitted'
    env.log('injected_console_hook',{hook=hook,ms=env.time(),frame=frame})
    return hook==2 and 1 or true
  end
  function p:render()
    if not self.running then return end
    self.renders=self.renders+1
    local now=env.time()
    if self.lastRender and now-self.lastRender>1000 then
      env.log('render_gap',{ms=now-self.lastRender,renders=self.renders,updates=self.updates,game_frame=env.frame()})
    end
    self.lastRender=now
    if self.deadline and now>=self.deadline then
      self.deadline=nil;self.status=next(self.emitted) and 'request_finished_result_unverified' or 'request_expired_no_hook'
      self:snapshot('F6_request_finished')
    end
  end
  function p:update() if self.running then self.updates=self.updates+1 end end
  function p:report() return {version=1,status=self.status,renders=self.renders,updates=self.updates,marks=self.marks,console_hook_samples=self.samples,game_verified=false} end
  return p
end
return M
