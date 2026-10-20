-- Raw Xbox bumpers: LB=8, RB=11. Never combine buttons from different pads.
local M={}
function M.new(down,now)
  local h={started=nil,index=nil,latched=false,active=false}
  function h:sample(index)
    local any,both=false,nil
    local first,last=1,4
    if index>0 then first=index;last=index end
    for pad=first,last do
      local left,right=down(8,pad),down(11,pad)
      any=any or left or right
      if left and right and (not self.index or self.index==pad) then both=pad end
    end
    return any,both
  end
  function h:update(enabled,index)
    local any,both=self:sample(index)
    if not any then self.started=nil;self.index=nil;self.latched=false;self.active=false;return false end
    if not enabled then self.started=nil;self.latched=true;self.active=false;return false end
    if self.latched then return false end
    if not both then self.started=nil;return false end
    self.active=true
    local time=now()
    if not self.started then self.started=time;self.index=both end
    if time<self.started then self.started=time end
    if time-self.started>=600 then self.latched=true;return true end
    return false
  end
  return h
end
return M
