-- Raw controller D-pad Up=2; analog stick and keyboard arrows are not hotkeys.
local M={}
function M.new(down,getButton)
  local h={latched=false,active=false}
  function h:sample(index)
    local button=getButton and getButton() or 2
    if button<0 then return false end
    if index>0 then return down(button,index) end
    for pad=1,4 do if down(button,pad) then return true end end
    return false
  end
  function h:update(enabled,index)
    local pressed=self:sample(index)
    if not pressed then self.latched=false;self.active=false;return false end
    if not enabled then self.latched=true;self.active=false;return false end
    if self.latched then return false end
    self.active=true;self.latched=true
    return true
  end
  return h
end
return M
