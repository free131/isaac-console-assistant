-- Raw Xbox bumpers: LB=8, RB=11. Never combine buttons from different pads.
local M={}
function M.new(down,now)
  local h={index=nil,latched=false,active=false,pending={}}
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
    if not enabled then self.pending={};self.latched=true;self.active=false;return false end
    if self.latched then return false end
    if not both then return false end
    self.active=true;self.index=both;self.latched=true;self.pending={}
    return true
  end
  function h:cancel_game() self.pending={} end
  -- Native input is queried before rendering. Buffer only bomb/item/card actions
  -- briefly so a one-frame shoulder stagger cannot execute before the chord.
  -- This is NOT a chord hold threshold: a complete chord fires immediately.
  function h:filter_game(action,hook,index,frame,pressed,enabled)
    local any,both=self:sample(index)
    if not enabled or both or self.active then self.pending={};return nil end
    local row=self.pending[action]
    if not row and any and pressed then row={time=now()};self.pending[action]=row end
    if not row then return nil end
    if row.done then
      if not any then self.pending[action]=nil end
      return nil
    end
    local time=now()
    if time<row.time then row.time=time end
    if time-row.time<90 then return hook==2 and 0 or false end
    if not row.frame then row.frame=frame end
    if row.frame==frame then return hook==2 and 1 or true end
    row.done=true
    if not any then self.pending[action]=nil end
    return nil
  end
  return h
end
return M
