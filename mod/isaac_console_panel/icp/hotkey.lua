-- Raw Xbox bumpers: LB=8, RB=11. Never combine buttons from different pads.
local M={}
function M.new(down)
  local h={index=nil,latched=false,active=false}
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
    if not any then self.index=nil;self.latched=false;self.active=false;return false end
    if not enabled then self.latched=true;self.active=false;return false end
    if self.latched then return false end
    if not both then return false end
    self.active=true;self.index=both;self.latched=true
    return true
  end
  return h
end
return M
