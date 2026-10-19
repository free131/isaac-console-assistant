local M={}
function M.new(categories,state)
  local font=Font();font:Load('mods/isaac_console_panel/resources/font/icp_panel.fnt')
  local rect=Sprite();rect:Load('gfx/icp/rect.anm2',true);rect:Play('Idle',true)
  local r={font=font,buttons={},scale=1,x=0,y=0}
  local function length(s) local _,n=s:gsub('[^\128-\191]','');return n end
  local function chars(s) return s:gmatch('[%z\1-\127\194-\244][\128-\191]*') end
  function r:box(x,y,w,h,color)
    rect.Scale=Vector(w*self.scale,h*self.scale);rect.Color=Color(color[1],color[2],color[3],color[4] or 1)
    rect:Render(Vector(self.x+x*self.scale,self.y+y*self.scale),Vector.Zero,Vector.Zero)
  end
  function r:text(s,x,y,size,color,width,lines)
    s=tostring(s or '');size=size or .75;color=color or {0.9,0.92,0.96,1}
    local line='';local count=0;local limit=lines or 1
    local function draw(t) font:DrawStringScaledUTF8(t,self.x+x*self.scale,self.y+(y+count*20*size)*self.scale,size*self.scale,size*self.scale,KColor(color[1],color[2],color[3],color[4] or 1),0,false) end
    for ch in chars(s) do
      local candidate=line..ch
      local w=font:GetStringWidthUTF8(candidate)*size
      if width and w>width then draw(line);count=count+1;if count>=limit then return end;line=ch else line=candidate end
    end
    draw(line)
  end
  function r:button(id,label,x,y,w,h,active)
    self:box(x,y,w,h,active and {.22,.36,.46} or {.14,.18,.23});self:text(label,x+7,y+5,.72,nil,w-12)
    self.buttons[#self.buttons+1]={id=id,x=x,y=y,w=w,h=h}
  end
  function r:draw(p)
    if not font:IsLoaded() then Isaac.RenderText('ICP font missing - check installation folder',10,30,1,.4,.4,1);return end
    self.scale=math.min((Isaac.GetScreenWidth()-16)/760,(Isaac.GetScreenHeight()-16)/450,1.5)
    self.x=(Isaac.GetScreenWidth()-760*self.scale)/2;self.y=(Isaac.GetScreenHeight()-450*self.scale)/2;self.buttons={}
    self:box(0,0,760,450,{.045,.06,.085,.97})
    self:text('以撒指令面板',15,12,1.1);self:text('v0.1 · Repentance 1.7.9b',430,18,.7)
    self:button('hotkey',state.hotkey:gsub('KEY_','')..' · 点击改键',600,10,145,30)
    self:box(14,50,655,31,{.11,.15,.20});self:text(p.query=='' and '直接输入拼音、首字母或 ID：shengxin / c515 / jinbi2' or p.query..'_',22,57,.75,nil,640)
    self:button('clear','清空',680,50,65,31)
    for i,c in ipairs(categories) do self:button('cat:'..c[1],c[2],14,90+(i-1)*25,132,23,p.category==c[1]) end
    self:text('结果 '..#p.hits..' 条',160,91,.7)
    local rows=p:visible()
    for n,row in ipairs(rows) do
      local e=row.hit.entry;self:button('row:'..row.index,(state.favorites[e.key] and '★ ' or '')..e.name,158,116+(n-1)*29,279,27,row.index==p.selected)
    end
    if #rows==0 then self:text('没有结果。试试更短的拼音或 ID。',169,136,.75,nil,250,3) end
    self:button('prev','上一页',158,355,85,27);self:text((p:page()+1)..' / '..math.max(1,math.ceil(#p.hits/8)),263,361,.7);self:button('next','下一页',352,355,85,27)
    local e=p:entry()
    if e then
      self:text(e.name,454,92,.95,nil,285,2);self:text(e.key,454,131,.65,nil,285)
      self:text(e.description,454,155,.73,nil,285,5)
      if e.action=='card' or e.action=='pill' then self:text('注意：可能替换口袋栏中的物品。',454,233,.65,nil,285)
      elseif e.action=='collectible' then self:text('主动道具可能替换当前主动栏。',454,233,.65,nil,285) end
      if e.action=='ability' then self:text('本 Mod 状态：'..(state.run[e.ability] and '开启' or '关闭'),454,233,.75) end
      self:button('minus','－',454,260,36,29);self:text('数量：'..p.amount,504,266,.8);self:button('plus','＋',700,260,36,29)
      self:button('operation',({give='操作：获取 / 执行',remove='操作：移除',on='操作：开启',off='操作：关闭'})[p.operation] or p.operation,454,299,282,29)
      self:button('favorite',state.favorites[e.key] and '取消收藏' or '收藏',454,340,95,33)
      self:button('execute',p.confirm and p.confirm>p.tick and '再次确认执行' or '确认执行',560,340,176,33,p.confirm and p.confirm>p.tick)
    end
    if p.category=='history' then self:button('delete','删此条',14,370,63,25);self:button('clear-history','清历史',82,370,64,25) end
    self:text(p.message,158,389,.67,{.94,.76,.38,1},585,2)
    self:text('游戏不会暂停，角色仍可能受到伤害。',15,419,.78,{1,.48,.42,1},415)
    self:text('↑↓选择  ←→数量  Enter确认  Esc返回',421,420,.59,nil,325)
  end
  function r:hit(x,y)
    x=(x-self.x)/self.scale;y=(y-self.y)/self.scale
    for _,b in ipairs(self.buttons) do if x>=b.x and y>=b.y and x<b.x+b.w and y<b.y+b.h then return b.id end end
  end
  return r
end
return M
