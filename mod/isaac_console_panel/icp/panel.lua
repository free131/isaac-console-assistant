local M={}
M.categories={{'all','全部'},{'collectibles','道具'},{'trinkets','饰品'},{'cards','卡牌 / 符文'},{'pills','胶囊'},{'resources','资源'},{'abilities','能力'},{'stages','楼层'},{'flow','房间 / 重开'},{'favorites','收藏'},{'history','历史'}}
M.keyboard={}
M.keyboardRows={}
for row,letters in ipairs({'1234567890-','qwertyuiop','asdfghjkl','zxcvbnm'}) do
  M.keyboardRows[row]={}
  for col=1,#letters do
    local ch=letters:sub(col,col)
    M.keyboard[#M.keyboard+1]={value=ch,label=ch:upper(),row=row,col=col,x=8+(11-#letters)*49/2+(col-1)*49,y=(row-1)*33,w=44,h=28}
    M.keyboardRows[row][col]=#M.keyboard
  end
end
M.keyboardRows[5]={}
for col,key in ipairs({{' ','空格',8,240},{'backspace','退格',258,130},{'done','完成',398,144}}) do
  M.keyboard[#M.keyboard+1]={value=key[1],label=key[2],row=5,col=col,x=key[3],y=132,w=key[4],h=28}
  M.keyboardRows[5][col]=#M.keyboard
end
function M.new(search,catalog,state,actions,save,record)
  local p={open=false,query='',category='all',selected=1,hits={},amount=1,operation='give',tick=0,message='',guard=false,focus='results',control=1}
  function p:controls()
    local ids={'quantity','operation','favorite','execute'}
    if self.category=='history' then ids[#ids+1]='delete';ids[#ids+1]='clear-history' end
    ids[#ids+1]='clear';ids[#ids+1]='search';ids[#ids+1]='hotkey';ids[#ids+1]='close'
    return ids
  end
  function p:control_id() local ids=self:controls();self.control=math.max(1,math.min(self.control,#ids));return ids[self.control] end
  function p:focus_search()
    if self.focus~='search' then self.searchFrom=self.focus end
    self.focus='search'
  end
  function p:focus_move(delta)
    local order={'search','categories','results','details'};local n=3
    for i,v in ipairs(order) do if self.focus==v then n=i end end
    local nextFocus=order[(n-1+delta)%#order+1]
    if nextFocus=='search' then self:focus_search() else self.focus=nextFocus end
    if self.focus=='details' then self.control=1 end
  end
  function p:navigate(dx,dy)
    if dy~=0 then
      if self.focus=='search' then
        if dy>0 then self.focus=self.searchFrom or 'results' end
      elseif self.focus=='categories' then
        local at=1;for i,c in ipairs(M.categories) do if c[1]==self.category then at=i end end
        if (dy<0 and at==1) or (dy>0 and at==#M.categories) then self:focus_search() else self:category_move(dy) end
      elseif self.focus=='results' then
        if #self.hits==0 or (dy<0 and self.selected<=1) then self:focus_search() else self:select(self.selected+dy) end
      else
        if (dy<0 and self.control<=1) or (dy>0 and self.control>=#self:controls()) then self:focus_search()
        else self.control=self.control+dy end
      end
    end
    if dx~=0 then
      if self.focus=='details' and self:control_id()=='quantity' then self:adjust(dx)
      elseif dx>0 then if self.focus=='categories' then self.focus='results' elseif self.focus=='results' then self.focus='details';self.control=1 end
      else if self.focus=='details' then self.focus='results' elseif self.focus=='results' then self.focus='categories' end end
    end
  end
  function p:confirm_id()
    if self.focus=='search' then return 'search' end
    if self.focus=='categories' then self.focus='results';return nil end
    if self.focus=='results' then return 'execute' end
    return self:control_id()
  end
  function p:open_search()
    self.editing=true;self.keyboardIndex=1;self.keyboardAimX=nil
    if self.category=='history' then self.category='all';self:refresh(self.greed) end
  end
  function p:keyboard_move(dx,dy)
    local key=M.keyboard[self.keyboardIndex or 1]
    if dx~=0 then
      local row=M.keyboardRows[key.row]
      self.keyboardIndex=row[(key.col-1+dx)%#row+1]
      self.keyboardAimX=nil
      key=M.keyboard[self.keyboardIndex]
    end
    if dy~=0 then
      local aim=self.keyboardAimX or (key.x+key.w/2)
      local row=M.keyboardRows[(key.row-1+dy)%#M.keyboardRows+1]
      local best,distance=row[1],math.huge
      for _,index in ipairs(row) do
        local target=M.keyboard[index];local d=math.abs(target.x+target.w/2-aim)
        if d<distance then best=index;distance=d end
      end
      self.keyboardIndex=best;self.keyboardAimX=aim
    end
  end
  function p:keyboard_confirm()
    local value=M.keyboard[self.keyboardIndex or 1].value
    if value=='done' then self.editing=false;self.focus='results'
    elseif value=='backspace' then self:set_query(self.query:sub(1,-2))
    else self:set_query(self.query..value) end
  end
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
  function p:close() self.open=false;self.editing=false;self.guard=true;self:changed() end
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
  function p:back(closeRoot)
    if self.editing then self.editing=false;self.focus='results';self.message='输入完成，已返回搜索结果。'
    elseif self.confirm or self.clearConfirm then self:changed();self.clearConfirm=nil;self.message='已取消确认。'
    elseif self.focus=='search' then self.focus=self.searchFrom or 'results';self.message='已返回结果列表。'
    elseif self.focus=='details' then self.focus='results';self.message='已返回结果列表。'
    elseif self.query~='' then self:set_query('');self.message='已清空搜索，返回当前分类。'
    elseif self.category~='all' then self.category='all';self:refresh(self.greed);self.focus='results';self.message='已返回全部列表。'
    elseif closeRoot then self:close()
    else self.focus='results';self.message='已在主列表；按打开热键关闭面板。' end
  end
  function p:page() return math.floor((self.selected-1)/8) end
  function p:visible() local rows={};for i=self:page()*8+1,math.min(#self.hits,self:page()*8+8) do rows[#rows+1]={index=i,hit=self.hits[i]} end;return rows end
  return p
end
return M
