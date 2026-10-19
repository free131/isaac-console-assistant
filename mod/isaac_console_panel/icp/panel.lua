local M={}
M.categories={{'all','全部'},{'collectibles','道具'},{'trinkets','饰品'},{'cards','卡牌 / 符文'},{'pills','胶囊'},{'resources','资源'},{'abilities','能力'},{'stages','楼层'},{'flow','房间 / 重开'},{'favorites','收藏'},{'history','历史'}}
function M.new(search,catalog,state,actions,save,record)
  local p={open=false,query='',category='all',selected=1,hits={},amount=1,operation='give',tick=0,message='',guard=false}
  function p:entry() return self.hits[self.selected] and self.hits[self.selected].entry end
  function p:changed() self.confirm=nil end
  function p:select(index)
    self.selected=math.max(1,math.min(index,math.max(1,#self.hits)));self:changed()
    local hit=self.hits[self.selected];local e=hit and hit.entry
    self.amount=hit and (hit.amount or e.default) or 1
    self.operation=hit and hit.operation or (e and e.action=='ability' and (state.run[e.ability] and 'off' or 'on') or 'give')
  end
  function p:refresh(greed)
    self.greed=greed
    self.hits=self.category=='history' and search.history(catalog,state) or search.query(catalog,self.query,self.category,state,greed)
    self:select(1)
  end
  function p:set_query(q) self.query=q:sub(1,64);self:refresh(self.greed) end
  function p:category_move(delta)
    local index=1;for i,c in ipairs(M.categories) do if c[1]==self.category then index=i end end
    self.category=M.categories[(index-1+delta)%#M.categories+1][1];self:refresh(self.greed)
  end
  function p:adjust(delta)
    local e=self:entry();if not e then return end
    self.amount=math.max(e.minimum,math.min(e.maximum,self.amount+delta));self:changed()
  end
  function p:toggle_operation()
    local e=self:entry();if not e then return end
    if e.action=='ability' then self.operation=self.operation=='on' and 'off' or 'on'
    elseif e.removable then self.operation=self.operation=='give' and 'remove' or 'give' end
    self:changed()
  end
  function p:request() local e=self:entry();return e and {key=e.key,amount=self.amount,operation=self.operation} end
  function p:close() self.open=false;self.guard=true;self:changed() end
  function p:execute()
    local req=self:request();if not req then self.message='没有可执行的结果。';return end
    local e,err=actions:validate(req);if not e then self.message=err;return end
    if e.danger and not (self.confirm and self.confirm>self.tick) then self.confirm=self.tick+240;self.message='再次确认将执行 '..e.name..'。';return end
    self:changed()
    local result=actions:execute(req);self.message=result.message
    if result.ok then record(req);save();if result.close then self:close() end end
  end
  function p:favorite()
    local e=self:entry();if e then state.favorites[e.key]=not state.favorites[e.key] or nil;save();if self.category=='favorites' then self:refresh(self.greed) end end
  end
  function p:history_delete()
    local hit=self.hits[self.selected]
    if self.category=='history' and hit then for i,row in ipairs(state.history) do if row==hit.recorded then table.remove(state.history,i);break end end;save();self:refresh(self.greed) end
  end
  function p:back() if self.confirm then self:changed();self.message='已取消确认。' else self:close() end end
  function p:page() return math.floor((self.selected-1)/8) end
  function p:visible() local rows={};for i=self:page()*8+1,math.min(#self.hits,self:page()*8+8) do rows[#rows+1]={index=i,hit=self.hits[i]} end;return rows end
  return p
end
return M
